# spec/models/datafile_spec.rb
require 'rails_helper'

RSpec.describe Datafile, type: :model do
  let(:dataset) { create(:dataset) }
  let(:datafile) { build(:datafile, dataset: dataset) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(datafile).to be_valid
    end

    it 'is not valid without a dataset' do
      datafile.dataset = nil
      expect(datafile).to_not be_valid
    end

    it 'is not valid without a binary_name' do
      datafile.binary_name = nil
      expect(datafile).to_not be_valid
    end

    it 'is not valid without a web_id' do
      datafile.web_id = nil
      datafile.save
      expect(datafile.web_id).to be_present
    end
  end

  describe 'associations' do
    it { should belong_to(:dataset) }
    it { should have_many(:nested_items).dependent(:destroy) }
  end

  describe 'callbacks' do
    it 'generates a web_id before creation' do
      datafile.save
      expect(datafile.web_id).to be_present
    end

    it 'sets dataset nested_updated_at after creation' do
      expect(dataset).to receive(:update_attribute).with(:nested_updated_at, anything)
      datafile.save
    end

    it 'sets dataset nested_updated_at before destruction' do
      datafile.save
      expect(dataset).to receive(:update_attribute).with(:nested_updated_at, anything)
      datafile.destroy
    end
  end

  describe '#to_param' do
    it 'returns the web_id as the parameter' do
      expect(datafile.to_param).to eq(datafile.web_id)
    end
  end

  describe '#as_json' do
    it 'returns a JSON representation of the datafile' do
      json = datafile.as_json
      expect(json).to include('web_id', 'binary_name', 'binary_size', 'medusa_id', 'storage_root', 'storage_key', 'created_at', 'updated_at')
    end
  end

  describe '#set_dataset_nested_updated_at' do
    it 'sets the nested_updated_at attribute of the dataset to the current time' do
      datafile.save
      expect(dataset.nested_updated_at).to be_within(1.second).of(Time.now.utc)
    end
  end

  describe '#bytestream_name' do
    it 'returns the binary_name' do
      expect(datafile.bytestream_name).to eq(datafile.binary_name)
    end
  end

  describe '#bytestream_size' do
    it 'returns the binary_size if it is set' do
      datafile.binary_size = 1024
      expect(datafile.bytestream_size).to eq(1024)
    end

    it 'returns 0 and logs a warning if the binary is not found' do
      allow(datafile).to receive(:current_root).and_return(nil)
      expect(Rails.logger).to receive(:warn).with("binary not found for datafile: #{datafile.web_id} root: #{datafile.storage_root}, key: #{datafile.storage_key}")
      expect(datafile.bytestream_size).to eq(0)
    end
  end

  describe '#s3_object' do
    it 'returns nil if the file does not exist on storage' do
      allow(datafile).to receive(:exists_on_storage?).and_return(false)
      expect(datafile.s3_object).to be_nil
    end
  end

  describe '#etag' do
    it 'returns the etag of the S3 object if it exists' do
      s3_object = double('s3_object', etag: 'etag_value')
      allow(datafile).to receive(:s3_object).and_return(s3_object)
      expect(datafile.etag).to eq('etag_value')
    end

    it 'returns nil if the S3 object does not exist' do
      allow(datafile).to receive(:s3_object).and_return(nil)
      expect(datafile.etag).to be_nil
    end
  end

  describe '#name' do
    it 'returns the binary_name' do
      expect(datafile.name).to eq(datafile.binary_name)
    end
  end

  describe '#ensure_mime_type' do
    it 'sets the mime type if it is not set' do
      datafile.mime_type = nil
      allow(datafile).to receive(:mime_type_from_name).and_return('text/plain')
      datafile.ensure_mime_type
      expect(datafile.mime_type).to eq('text/plain')
    end
  end

  describe '#readme?' do
    it 'returns true if the binary_name includes "readme"' do
      datafile.binary_name = 'README.txt'
      expect(datafile.readme?).to be true
    end

    it 'returns false if the binary_name does not include "readme"' do
      datafile.binary_name = 'sample.txt'
      expect(datafile.readme?).to be false
    end
  end

  describe '#generate_web_id' do
    it 'generates a unique web_id' do
      web_id = datafile.generate_web_id
      expect(Datafile.find_by(web_id: web_id)).to be_nil
    end
  end

  describe '.peek_type_from_mime' do
    it 'returns none when mime type is missing or malformed' do
      expect(Datafile.peek_type_from_mime(nil, 100)).to eq(Databank::PeekType::NONE)
      expect(Datafile.peek_type_from_mime('text', 100)).to eq(Databank::PeekType::NONE)
    end

    it 'returns markdown for markdown mime top-level type' do
      expect(Datafile.peek_type_from_mime('markdown/plain', 100)).to eq(Databank::PeekType::MARKDOWN)
    end

    it 'returns all_text for small text and part_text for large text' do
      small = Datafile::Viewable::ALLOWED_DISPLAY_BYTES - 1
      large = Datafile::Viewable::ALLOWED_DISPLAY_BYTES + 1

      expect(Datafile.peek_type_from_mime('text/plain', small)).to eq(Databank::PeekType::ALL_TEXT)
      expect(Datafile.peek_type_from_mime('text/plain', large)).to eq(Databank::PeekType::PART_TEXT)
    end

    it 'maps supported media/document mime types' do
      expect(Datafile.peek_type_from_mime('image/png', 100)).to eq(Databank::PeekType::IMAGE)
      expect(Datafile.peek_type_from_mime('application/pdf', 100)).to eq(Databank::PeekType::PDF)
      expect(Datafile.peek_type_from_mime('application/zip', 100)).to eq(Databank::PeekType::LISTING)
      expect(Datafile.peek_type_from_mime('application/msword', 100)).to eq(Databank::PeekType::MICROSOFT)
      expect(Datafile.peek_type_from_mime('image/webp', 100)).to eq(Databank::PeekType::NONE)
    end
  end

  describe '#handle_peek' do
    it 'renders markdown preview and saves markdown peek type' do
      datafile.binary_name = 'notes.md'
      allow(datafile).to receive(:all_text_peek).and_return('# Header')
      renderer = double('markdown_renderer', render: '<h1>Header</h1>')
      allow(Application).to receive(:markdown).and_return(renderer)

      expect(datafile.handle_peek).to be true
      expect(datafile.peek_type).to eq(Databank::PeekType::MARKDOWN)
      expect(datafile.peek_text).to eq('<h1>Header</h1>')
    end

    it 'handles listing peek type by starting processing task' do
      datafile.binary_name = 'archive.zip'
      datafile.mime_type = 'application/zip'
      datafile.binary_size = 500
      allow(datafile).to receive(:initiate_processing_task).and_return(true)

      expect(datafile.handle_peek).to be true
      expect(datafile).to have_received(:initiate_processing_task)
    end
  end

  describe '#part_text_peek' do
    it 'returns file not found when storage object is missing' do
      root = double('storage_root', exist?: false)
      allow(datafile).to receive(:current_root).and_return(root)

      expect(datafile.part_text_peek).to eq('file not found')
    end

    it 'returns decoded bytes in s3 mode' do
      config_copy = IDB_CONFIG.deep_dup
      config_copy[:aws][:s3_mode] = true
      stub_const('IDB_CONFIG', config_copy)

      raw = StringIO.new("abc\u0000def")
      root = double('storage_root', exist?: true, get_bytes: raw)
      allow(datafile).to receive(:current_root).and_return(root)

      expect(datafile.part_text_peek).to eq('abcdef')
    end
  end

  describe '#all_text_peek' do
    it 'returns full file contents in local filesystem mode' do
      config_copy = IDB_CONFIG.deep_dup
      config_copy[:aws][:s3_mode] = false
      stub_const('IDB_CONFIG', config_copy)

      root = double('storage_root', exist?: true)
      allow(datafile).to receive(:current_root).and_return(root)

      Dir.mktmpdir('viewable-local-peek') do |dir|
        path = File.join(dir, 'peek.txt')
        File.write(path, 'full file preview')
        allow(datafile).to receive(:filepath).and_return(path)

        expect(datafile.all_text_peek).to eq('full file preview')
      end
    end
  end
end
