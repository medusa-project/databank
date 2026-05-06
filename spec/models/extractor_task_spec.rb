require 'rails_helper'

RSpec.describe ExtractorTask, type: :model do
  let(:dataset) { create(:dataset) }
  let(:datafile) { create(:datafile, dataset: dataset, web_id: 'abc12', binary_name: 'archive.zip', mime_type: 'application/zip') }

  describe 'validations' do
    it 'requires web_id' do
      task = ExtractorTask.new(web_id: nil)

      expect(task).not_to be_valid
      expect(task.errors[:web_id]).to include("can't be blank")
    end
  end

  describe '#command_string' do
    it 'returns nil when no datafile matches the task web_id' do
      task = ExtractorTask.new(web_id: 'missing')

      expect(task.command_string).to be_nil
    end

    it 'builds the extractor command string from datafile storage fields' do
      task = ExtractorTask.new(web_id: datafile.web_id)
      allow(Datafile).to receive(:find_by).with(web_id: datafile.web_id).and_return(datafile)
      allow(datafile).to receive(:storage_root_bucket).and_return('draft-bucket')
      allow(datafile).to receive(:storage_key_with_prefix).and_return('uploads/archive.zip')

      expect(task.command_string).to eq("Extractor.extract 'draft-bucket', 'uploads/archive.zip', 'archive.zip', 'abc12', 'application/zip'")
    end
  end

  describe '.initiate_task_batch' do
    it 'returns nil when there are no unsent tasks' do
      allow(ExtractorTask).to receive(:where).with(sent_at: nil).and_return([])

      expect(ExtractorTask.initiate_task_batch).to be_nil
    end

    it 'returns nil when current task count has reached capacity' do
      unsent = [instance_double(ExtractorTask, datafile: datafile)]
      allow(ExtractorTask).to receive(:where).with(sent_at: nil).and_return(unsent)
      allow(Rails.env).to receive(:development?).and_return(false)
      allow(ExtractorTask).to receive(:current_tasks).and_return(Array.new(ExtractorTask::MAX_TASK_COUNT) { 'arn' })

      expect(ExtractorTask.initiate_task_batch).to be_nil
    end

    it 'destroys tasks with missing datafiles and initiates a limited batch of valid tasks' do
      missing = instance_double(ExtractorTask, datafile: nil)
      valid1 = instance_double(ExtractorTask, datafile: datafile)
      valid2 = instance_double(ExtractorTask, datafile: datafile)
      unsent = double(count: 3)
      limited = [valid1, valid2]

      allow(ExtractorTask).to receive(:where).with(sent_at: nil).and_return(unsent)
      allow(unsent).to receive(:each).and_yield(missing).and_yield(valid1).and_yield(valid2)
      allow(Rails.env).to receive(:development?).and_return(false)
      allow(ExtractorTask).to receive(:current_tasks).and_return([])
      allow(unsent).to receive(:limit).with(ExtractorTask::MAX_BATCH_COUNT).and_return(limited)
      expect(missing).to receive(:destroy)
      expect(valid1).to receive(:initiate_task).and_return(:sent1)
      expect(valid2).to receive(:initiate_task).and_return(:sent2)

      expect(ExtractorTask.initiate_task_batch).to eq([:sent1, :sent2])
    end
  end

  describe '.current_tasks' do
    it 'raises when ECS response lacks task_arns' do
      bad_response = double(task_arns: nil, to_yaml: 'bad-task-list')
      allow(ExtractorTask::ECS_CLIENT).to receive(:list_tasks).with(cluster: ExtractorTask::CLUSTER).and_return(bad_response)

      expect { ExtractorTask.current_tasks }.to raise_error(StandardError, /unexpected task_list/)
    end
  end

  describe '.fetch_incoming_message' do
    it 'returns nil when queue has no messages' do
      response = double(data: double(messages: []))
      allow(ExtractorTask::SQS).to receive(:receive_message).and_return(response)

      expect(ExtractorTask.fetch_incoming_message).to be_nil
    end

    it 'raises when message file is missing from message root' do
      sqs_message = double(body: { 'object_key' => 'extractor/abc12.json' }.to_json, receipt_handle: 'receipt-1')
      response = double(data: double(messages: [sqs_message]))
      allow(ExtractorTask::SQS).to receive(:receive_message).and_return(response)
      allow(ExtractorTask::SQS).to receive(:delete_message)
      allow(ExtractorTask::MESSAGE_ROOT).to receive(:exist?).with('abc12.json').and_return(false)

      expect { ExtractorTask.fetch_incoming_message }.to raise_error(StandardError, /extractor task message not found/)
    end

    it 'returns parsed web_id and message text when queue message and file exist' do
      sqs_message = double(body: { 'object_key' => 'extractor/abc12.json' }.to_json, receipt_handle: 'receipt-1')
      response = double(data: double(messages: [sqs_message]))
      allow(ExtractorTask::SQS).to receive(:receive_message).and_return(response)
      allow(ExtractorTask::SQS).to receive(:delete_message)
      allow(ExtractorTask::MESSAGE_ROOT).to receive(:exist?).with('abc12.json').and_return(true)
      allow(ExtractorTask::MESSAGE_ROOT).to receive(:as_string).with('abc12.json').and_return('{"status":"success"}')
      expect(ExtractorTask::MESSAGE_ROOT).to receive(:delete_content).with('abc12.json')

      expect(ExtractorTask.fetch_incoming_message).to eq(message_web_id: 'abc12', message_text: '{"status":"success"}')
      expect(ExtractorTask::SQS).to have_received(:delete_message)
    end
  end

  describe '.handle_incoming_message' do
    it 'raises when no datafile is found for the message web_id' do
      allow(Datafile).to receive(:find_by).with(web_id: 'missing').and_return(nil)

      expect do
        ExtractorTask.handle_incoming_message(message_web_id: 'missing', message_text: '{}')
      end.to raise_error(StandardError, /no Datafile found for archive extractor response message: missing/)
    end
  end

  describe '.record_response' do
    it 'raises when no extractor task is attached to the datafile' do
      allow(datafile).to receive(:extractor_task).and_return(nil)

      expect do
        ExtractorTask.record_response(datafile: datafile, message_text: '{}')
      end.to raise_error(StandardError, /no extractor_task/)
    end

    it 'updates datafile preview fields and creates nested items on successful response' do
      task = ExtractorTask.create!(web_id: datafile.web_id)
      message_hash = {
        'web_id' => datafile.web_id,
        'status' => Databank::ExtractionStatus::SUCCESS,
        'peek_type' => 'listing',
        'peek_text' => 'preview text',
        'nested_items' => [
          {
            'item_name' => 'inner.txt',
            'item_path' => 'folder/inner.txt',
            'media_type' => 'text/plain',
            'item_size' => 123,
            'is_directory' => 'false'
          }
        ]
      }

      allow(datafile).to receive(:extractor_task).and_return(task)

      expect do
        ExtractorTask.record_response(datafile: datafile, message_text: message_hash.to_json)
      end.to change(ExtractorResponse, :count).by(1)
        .and change(NestedItem, :count).by(1)

      expect(datafile.reload.peek_type).to eq('listing')
      expect(datafile.peek_text).to eq('preview text')
      expect(task.reload.response_at).to be_present
      expect(task.raw_response).to eq(message_hash.to_json)
    end
  end

  describe '.handle_extracted_nested_items' do
    it 'returns nil when nested_items is empty or non-enumerable' do
      expect(ExtractorTask.handle_extracted_nested_items(datafile: datafile, nested_items: nil)).to be_nil
      expect(ExtractorTask.handle_extracted_nested_items(datafile: datafile, nested_items: [])).to be_nil
    end
  end
end
