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
end