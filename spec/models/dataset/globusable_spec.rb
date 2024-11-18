# spec/models/dataset/globusable_spec.rb
require 'rails_helper'

RSpec.describe Dataset::Globusable, type: :model do
  let(:dataset) { create(:dataset) }
  let(:datafile) { create(:datafile, dataset: dataset) }

  before do
    dataset.extend(Dataset::Globusable)
  end

  describe '#globus_downloadable?' do
    
    it 'returns false if publication state is not released' do
      allow(dataset).to receive(:publication_state).and_return(Databank::PublicationState::DRAFT)
      expect(dataset.globus_downloadable?).to be_falsey
    end

    it 'returns true if all conditions are met' do
      allow(dataset).to receive(:publication_state).and_return(Databank::PublicationState::RELEASED)
      allow(Rails.env).to receive(:test?).and_return(false)
      allow(Rails.env).to receive(:development?).and_return(false)
      allow(StorageManager.instance.globus_download_root).to receive(:exist?).and_return(true)
      expect(dataset.globus_downloadable?).to be_truthy
    end
  end

  describe '#globus_download_dir' do
    it 'returns the correct download directory URL' do
      expect(dataset.globus_download_dir).to eq("#{GLOBUS_CONFIG[:download_url_base]}#{dataset.key}")
    end
  end

  describe '#ensure_globus_ingest_dir' do
    it 'returns true if the ingest directory exists' do
      allow(StorageManager.instance.globus_ingest_root).to receive(:exist?).and_return(true)
      expect(dataset.ensure_globus_ingest_dir).to be true
    end

    it 'returns nil if S3 mode is not enabled' do
      allow(IDB_CONFIG[:aws]).to receive(:[]).with(:s3_mode).and_return(false)
      expect(dataset.ensure_globus_ingest_dir).to be_nil
    end
  end

  describe '#globus_ingest_dir' do
    it 'returns the correct ingest directory URL' do
      expect(dataset.globus_ingest_dir).to eq("#{GLOBUS_CONFIG[:ingest_url_base]}#{dataset.key}")
    end
  end

  describe '#copy_to_globus_ingest_dir' do
    it 'raises an error if unable to ensure globus ingest directory' do
      allow(dataset).to receive(:ensure_globus_ingest_dir).and_return(false)
      expect { dataset.copy_to_globus_ingest_dir(source_root: 'root', source_key: 'key') }.to raise_error("unable to ensure globus ingest directory")
    end

    it 'copies content to the globus ingest directory' do
      allow(dataset).to receive(:ensure_globus_ingest_dir).and_return(true)
      allow(StorageManager.instance.globus_ingest_root).to receive(:copy_content_to).and_return(true)
      expect(dataset.copy_to_globus_ingest_dir(source_root: 'root', source_key: 'key')).to be_truthy
    end
  end

  describe '#import_from_globus' do
    it 'raises an error if no file is found on the Globus endpoint' do
      allow(StorageManager.instance.globus_ingest_root).to receive(:exist?).and_return(false)
      expect { dataset.import_from_globus }.to raise_error("No file found on Globus endpoint.")
    end
  end

  describe '#remove_from_globus_download' do
    it 'returns nil if the download directory does not exist' do
      allow(StorageManager.instance.globus_download_root).to receive(:exist?).and_return(false)
      expect(dataset.remove_from_globus_download).to be_nil
    end
  end

  describe '#remove_globus_ingest_dir' do
    it 'returns nil if the ingest directory does not exist' do
      allow(StorageManager.instance.globus_ingest_root).to receive(:exist?).and_return(false)
      expect(dataset.remove_globus_ingest_dir).to be_nil
    end
  end
end