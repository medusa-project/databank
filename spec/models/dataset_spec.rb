# spec/models/dataset_spec.rb
require 'rails_helper'

RSpec.describe Dataset, type: :model do
  let(:dataset) { build(:dataset) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(dataset).to be_valid
    end

    it 'is not valid without a dataset_version' do
      dataset.dataset_version = nil
      expect(dataset).to_not be_valid
    end
  end

  describe 'associations' do
    it { should have_many(:datafiles).dependent(:destroy) }
    it { should have_many(:version_files).dependent(:destroy) }
    it { should have_many(:creators).dependent(:destroy) }
    it { should have_many(:contributors).dependent(:destroy) }
    it { should have_many(:funders).dependent(:destroy) }
    it { should have_many(:related_materials).dependent(:destroy) }
    it { should have_many(:system_files).dependent(:destroy) }
    it { should have_many(:notes).dependent(:destroy) }
    it { should have_one(:share_code).dependent(:destroy) }
  end

  describe 'callbacks' do
    it 'sets the key before creation' do
      dataset.save
      expect(dataset.key).to be_present
    end

    it 'stores agreement after creation' do
      expect(dataset).to receive(:store_agreement)
      dataset.save
    end

    it 'ensures globus ingest directory after creation' do
      expect(dataset).to receive(:ensure_globus_ingest_dir)
      dataset.save
    end
  end

  describe '#metadata_public?' do
    it 'returns true if the dataset meets all criteria' do
      dataset.is_test = false
      dataset.publication_state = Databank::PublicationState::RELEASED
      dataset.hold_state = nil
      expect(dataset.metadata_public?).to be true
    end

    it 'returns false if the dataset is a test dataset' do
      dataset.is_test = true
      expect(dataset.metadata_public?).to be false
    end
  end

  describe '.all_with_public_metadata' do
    it 'filters datasets using metadata_public?' do
      public_dataset = instance_double(Dataset, metadata_public?: true)
      private_dataset = instance_double(Dataset, metadata_public?: false)

      allow(Dataset).to receive(:all).and_return([public_dataset, private_dataset])

      expect(Dataset.all_with_public_metadata).to eq([public_dataset])
    end
  end

  describe '#draft?' do
    it 'returns true if the publication state is draft' do
      dataset.publication_state = Databank::PublicationState::DRAFT
      expect(dataset.draft?).to be true
    end

    it 'returns false if the publication state is not draft' do
      dataset.publication_state = Databank::PublicationState::RELEASED
      expect(dataset.draft?).to be false
    end
  end

  describe '#files_public?' do
    it 'returns true if the publication state is released and the hold state is nil or file-only suppressed' do
      dataset.publication_state = Databank::PublicationState::RELEASED
      dataset.hold_state = nil
      expect(dataset.files_public?).to be true
    end

    it 'returns false if the publication state is not released' do
      dataset.publication_state = Databank::PublicationState::DRAFT
      expect(dataset.files_public?).to be false
    end
  end

  describe '#updated_datetime' do
    it 'uses the later of updated_at and nested_updated_at for drafts' do
      dataset.publication_state = Databank::PublicationState::DRAFT
      dataset.updated_at = Time.zone.parse('2026-05-01 10:00:00')
      dataset.nested_updated_at = Time.zone.parse('2026-05-03 12:00:00')

      expect(dataset.updated_datetime).to eq('2026-05-03')
    end

    it 'uses updated_at when not a draft and there is no changelog or nested update' do
      dataset.publication_state = Databank::PublicationState::RELEASED
      dataset.updated_at = Time.zone.parse('2026-05-01 10:00:00')
      dataset.nested_updated_at = nil
      allow(dataset).to receive(:display_changelog).and_return(nil)

      expect(dataset.updated_datetime).to eq('2026-05-01')
    end

    it 'uses the later nested update when not a draft and changelog is unavailable' do
      dataset.publication_state = Databank::PublicationState::RELEASED
      dataset.updated_at = Time.zone.parse('2026-05-01 10:00:00')
      dataset.nested_updated_at = Time.zone.parse('2026-05-03 12:00:00')
      allow(dataset).to receive(:display_changelog).and_return(nil)

      expect(dataset.updated_datetime).to eq('2026-05-03')
    end

    it 'uses a future release datetime when changelog is empty' do
      dataset.publication_state = Databank::PublicationState::RELEASED
      allow(dataset).to receive(:display_changelog).and_return([])
      allow(dataset).to receive(:release_datetime).and_return(2.days.from_now)

      expect(dataset.updated_datetime).to eq(2.days.from_now.to_date.iso8601)
    end

    it 'falls back to updated_at when changelog is empty and ingest datetime is missing' do
      dataset.publication_state = Databank::PublicationState::RELEASED
      dataset.updated_at = Time.zone.parse('2026-05-01 10:00:00')
      allow(dataset).to receive(:display_changelog).and_return([])
      allow(dataset).to receive(:release_datetime).and_return(1.day.ago)
      allow(dataset).to receive(:ingest_datetime).and_return(nil)

      expect(dataset.updated_datetime).to eq('2026-05-01')
    end

    it 'uses ingest datetime when changelog is empty and release datetime is not in the future' do
      dataset.publication_state = Databank::PublicationState::RELEASED
      ingest_time = Time.zone.parse('2026-05-04 09:30:00')
      allow(dataset).to receive(:display_changelog).and_return([])
      allow(dataset).to receive(:release_datetime).and_return(1.day.ago)
      allow(dataset).to receive(:ingest_datetime).and_return(ingest_time)

      expect(dataset.updated_datetime).to eq('2026-05-04')
    end

    it 'uses the newest changelog entry date when present' do
      dataset.publication_state = Databank::PublicationState::RELEASED
      allow(dataset).to receive(:display_changelog).and_return([{ created_at: Time.zone.parse('2026-05-05 08:00:00') }])

      expect(dataset.updated_datetime).to eq('2026-05-05')
    end
  end

  describe '#aggregate_downloadable?' do
    it 'returns true when preserved files are available and there are no external files' do
      allow(dataset).to receive(:fileset_preserved?).and_return(true)
      allow(dataset).to receive(:globus_downloadable?).and_return(false)
      allow(dataset).to receive(:has_external_files?).and_return(false)

      expect(dataset.aggregate_downloadable?).to be true
    end

    it 'returns false when external files are present' do
      allow(dataset).to receive(:fileset_preserved?).and_return(true)
      allow(dataset).to receive(:globus_downloadable?).and_return(false)
      allow(dataset).to receive(:has_external_files?).and_return(true)

      expect(dataset.aggregate_downloadable?).to be false
    end
  end

  describe '#has_external_files?' do
    it 'returns false when the external files note is blank' do
      dataset.external_files_note = ''

      expect(dataset.has_external_files?).to be false
    end

    it 'returns true when the external files note is present' do
      dataset.external_files_note = 'See external repository'

      expect(dataset.has_external_files?).to be true
    end
  end

  describe '#has_datafiles?' do
    it 'returns true when the dataset has at least one datafile' do
      allow(dataset).to receive_message_chain(:datafiles, :count).and_return(1)

      expect(dataset.has_datafiles?).to be true
    end
  end

  describe '#is_too_big?' do
    it 'returns true when total filesize is greater than the configured limit' do
      threshold = IDB_CONFIG[:globus_only_gb].to_i * (2**30)
      allow(dataset).to receive(:total_filesize).and_return(threshold + 1)

      expect(dataset.is_too_big?).to be true
    end
  end

  describe '#publication_year' do
    it 'returns the year of the release date if set' do
      dataset.release_date = Date.new(2020, 1, 1)
      expect(dataset.publication_year).to eq(2020)
    end

    it 'returns the current year if no release date is set' do
      dataset.release_date = nil
      expect(dataset.publication_year).to eq(Time.now.year)
    end
  end

  describe '#release_datetime' do
    it 'returns release_date as datetime for non-draft publication states' do
      dataset.publication_state = Databank::PublicationState::RELEASED
      dataset.release_date = Date.new(2026, 5, 5)

      expect(dataset.release_datetime).to eq(dataset.release_date.to_datetime)
    end
  end

  describe '#license_name' do
    it 'returns the name of the license for the dataset' do
      dataset.license = 'CCBY4'
      expect(dataset.license_name).to eq('CC BY')
    end

    it 'returns "License not selected" if no license is set' do
      dataset.license = nil
      expect(dataset.license_name).to eq('License not selected')
    end

    it 'returns the custom license message for license.txt' do
      dataset.license = 'license.txt'

      expect(dataset.license_name).to eq('See license.txt file in dataset.')
    end
  end

  describe '#databank_url' do
    it 'returns the URL text for the dataset' do
      dataset.key = '12345'
      expect(dataset.databank_url).to eq("#{IDB_CONFIG[:root_url_text]}/datasets/12345")
    end
  end

  describe '#persistent_url' do
    it 'returns the persistent URL for the dataset' do
      dataset.identifier = 'doi:10.1234/56789'
      expect(dataset.persistent_url).to eq("#{IDB_CONFIG[:datacite][:url_base]}/doi:10.1234/56789")
    end

    it 'returns an empty string if no identifier is set' do
      dataset.identifier = nil
      expect(dataset.persistent_url).to eq('')
    end
  end

  describe '#persistent_url_base' do
    it 'uses the test DataCite base for test datasets' do
      allow(dataset).to receive(:is_test?).and_return(true)

      expect(dataset.persistent_url_base).to eq(IDB_CONFIG[:datacite_test][:url_base])
    end
  end

  describe '#license_code' do
    it 'returns custom for text-file licenses' do
      dataset.license = 'custom-license.txt'

      expect(dataset.license_code).to eq('custom')
    end

    it 'returns unselected when the license is blank' do
      dataset.license = ''

      expect(dataset.license_code).to eq('unselected')
    end
  end

  describe '#mine_or_not_mine' do
    it 'returns "mine" if the email address matches the depositor email' do
      dataset.depositor_email = 'user@example.com'
      expect(dataset.mine_or_not_mine('user@example.com')).to eq('mine')
    end

    it 'returns "not_mine" if the email address does not match the depositor email' do
      dataset.depositor_email = 'user@example.com'
      expect(dataset.mine_or_not_mine('other@example.com')).to eq('not_mine')
    end
  end

  describe 'private #remove_system_files' do
    it 'deletes only existing system file content from draft storage' do
      existing_file = instance_double(SystemFile, storage_key: 'present-key')
      missing_file = instance_double(SystemFile, storage_key: 'missing-key')
      root = instance_double('draft_root')
      manager = instance_double(StorageManager, draft_root: root)

      allow(StorageManager).to receive(:instance).and_return(manager)
      allow(dataset).to receive(:system_files).and_return([existing_file, missing_file])
      allow(root).to receive(:exist?).with('present-key').and_return(true)
      allow(root).to receive(:exist?).with('missing-key').and_return(false)
      expect(root).to receive(:delete_content).with('present-key')
      expect(root).not_to receive(:delete_content).with('missing-key')

      dataset.send(:remove_system_files)
    end
  end
end