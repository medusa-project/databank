# frozen_string_literal: true

require 'rake'
require 'bunny'
require 'json'
require 'mime/types'
require 'aws-sdk-sqs'
require 'securerandom'

include Databank

namespace :databank_tasks do

  desc 'get and handle messages from databank-tasks-micro'
  task :handle_incoming_messages => :environment do
    incoming_messages = DatabankTask.fetch_incoming_messages
    DatabankTask.handle_incoming_messages(incoming_messages: incoming_messages)
  end

  desc 'create test sqs message'
  task :make_test_sqs_message => :environment do
    queue_url='https://sqs.us-east-2.amazonaws.com/721945215539/databank-to-medusa-demo.fifo'
    sqs = Aws::SQS::Client.new(region: 'us-east-2')
    sqs.send_message(queue_url: queue_url,
                     message_body: 'Hello world',
                     message_group_id: 'test',
                     message_duplication_id: SecureRandom.base64(10) )
  end
  desc 'fetch test sqs message'
  task :fetch_test_sqs_message => :environment do
    queue_url='https://sqs.us-east-2.amazonaws.com/721945215539/databank-to-medusa-demo.fifo'
    sqs = Aws::SQS::Client.new(region: 'us-east-2')
    resp = sqs.receive_message(queue_url: queue_url, max_number_of_messages: 10)
    resp.messages.each do |m|
      puts m.body
      # Delete the message from the queue.
      sqs.delete_message({
                           queue_url: queue_url,
                           receipt_handle: m.receipt_handle
                         })
    end
  end

  desc 'remove tasks from datafiles'
  task :remove_all_tasks => :environment do
    Datafile.all.each do |datafile|
      datafile.task_id = nil
      datafile.save
    end
  end

  desc 'set missing peek_info from mime_type and size'
  task :set_missing_peek_info => :environment do
    Datafile.set_missing_peek_info
  end

  desc 'import nested items and peek info from complete tasks'
  task :handle_ripe_tasks => :environment do
    Datafile.all.each do |datafile|
      if datafile&.task_id
        task_hash = DatabankTask.get_remote_task(datafile.task_id)

        if task_hash.has_key?('status') && task_hash['status'] == TaskStatus::RIPE

          # claim tasks
          DatabankTask.set_remote_task_status(datafile.task_id, TaskStatus::HARVESTING)

          if task_hash.has_key?('peek_type')
            datafile.peek_type = task_hash['peek_type']
          else
            datafile.peek_type = Databank::PeekType::NONE
          end

          if task_hash.has_key?('peek_text') && task_hash['peek_text'] != nil
            datafile.peek_text = task_hash['peek_text'].encode('utf-8')
          else
            datafile.peek_text = ""
          end

          datafile.save

          if datafile.peek_type == Databank::PeekType::LISTING

            remote_nested_items = DatabankTask.get_remote_items(datafile.task_id)
            remote_nested_items.each do |item|

              existing_items = NestedItem.where(datafile_id: datafile.id, item_path: item['item_path'])

              if existing_items.count > 0
                existing_items.each do |exising_item|
                  exising_item.destroy
                end
              end

              NestedItem.create(datafile_id: datafile.id,
                                item_name: item['item_name'],
                                item_path: item['item_path'],
                                media_type: item['media_type'],
                                size: item['item_size'],
                                is_directory: item['is_directory'] == "true" )
            end

          end

          # close tasks
          DatabankTask.set_remote_task_status(datafile.task_id, TaskStatus::HARVESTED)

        end

      end

    end
  end

  desc 'reset test harvesting tasks back to ripe'
  task :set_ripe => :environment do
    Datafile.all.each do |datafile|
      if datafile && datafile.task_id
        task_hash = DatabankTask.get_remote_task(datafile.task_id)
        if task_hash.has_key?('status') && task_hash['status'] == TaskStatus::HARVESTING
          DatabankTask.set_remote_task_status(datafile.task_id, TaskStatus::RIPE)
        end

      end

    end
  end

end