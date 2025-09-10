require 'rails_helper'

RSpec.describe Dataset::Globusable, type: :model do
  let(:dataset) { create(:dataset) }
  let(:datafile) { create(:datafile, dataset: dataset) }
  let(:storage_manager) { StorageManager.instance } # This is a singleton
  let(:draft_root) { storage_manager.draft_root }
  let(:globus_ingest_root) { storage_manager.globus_ingest_root }
  let(:globus_download_root) { storage_manager.globus_download_root }

  describe '#copy_to_globus_ingest_dir' do
    it 'raises an error if the source directory is not found' do
      allow(draft_root).to receive(:exist?).and_return(false)
      expect {
        dataset.copy_to_globus_ingest_dir(source_root_name: 'draft', source_key: 'nonexistent_key')
      }.to raise_error('source directory not found')
    end

    it 'copies content to the globus ingest directory' do
      allow(draft_root).to receive(:exist?).and_return(true)
      allow(dataset).to receive(:ensure_globus_ingest_dir).and_return(true)
      allow(globus_ingest_root).to receive(:copy_content_to)

      dataset.copy_to_globus_ingest_dir(source_root_name: 'draft', source_key: 'source_key')

      expect(globus_ingest_root).to have_received(:copy_content_to)
    end
  end

  describe '#globus_downloadable?' do
    it 'returns false if the dataset is not released' do
      allow(dataset).to receive(:publication_state).and_return(Databank::PublicationState::DRAFT)
      expect(dataset.globus_downloadable?).to be_falsey
    end

    it 'returns true if all datafiles are available in the globus download directory' do
      allow(dataset).to receive(:publication_state).and_return(Databank::PublicationState::RELEASED)
      allow(dataset).to receive(:datafiles).and_return([datafile])
      allow(globus_download_root).to receive(:exist?).and_return(true)

      expect(dataset.globus_downloadable?).to be_truthy
    end
  end

  describe '#import_from_globus' do

    it 'raises an error if files are not found on the Globus endpoint' do
      allow(globus_ingest_root).to receive(:exist?).and_return(false)
      expect {
        dataset.import_from_globus
      }.to raise_error('files not found on Globus endpoint')
    end


    context 'when a file exists in the Globus ingest directory' do
      before do
        dataset.copy_to_globus_ingest_dir(source_root_name: 'draft', source_key: 'testf/sample_file.txt')
      end
      after do
        dataset.remove_globus_ingest_dir
      end
      it 'imports files from the Globus ingest directory' do
        expect {
          dataset.import_from_globus
        }.to change { Datafile.count }.by(1)
      end
    end
  end

  describe '#remove_from_globus_download' do
    it 'removes files from the globus download directory' do
      allow(globus_download_root).to receive(:exist?).and_return(true)
      allow(globus_download_root).to receive(:file_keys).and_return(['key/file1.txt'])
      allow(globus_download_root).to receive(:delete_content)

      dataset.remove_from_globus_download

      expect(globus_download_root).to have_received(:delete_content).twice
    end
  end

  describe '#remove_globus_ingest_dir' do
    it 'removes files from the globus ingest directory' do
      allow(globus_ingest_root).to receive(:exist?).and_return(true)
      allow(globus_ingest_root).to receive(:file_keys).and_return(['key/file1.txt'])
      allow(globus_ingest_root).to receive(:delete_content)

      dataset.remove_globus_ingest_dir

      expect(globus_ingest_root).to have_received(:delete_content).twice
    end
  end
end