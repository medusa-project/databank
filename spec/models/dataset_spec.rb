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

  describe '#license_name' do
    it 'returns the name of the license for the dataset' do
      dataset.license = 'CCBY4'
      expect(dataset.license_name).to eq('CC BY')
    end

    it 'returns "License not selected" if no license is set' do
      dataset.license = nil
      expect(dataset.license_name).to eq('License not selected')
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
end