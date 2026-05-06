# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DatasetDownloadTally, type: :model do
  let(:dataset) do
    create(:dataset,
           key: 'TESTIDB-aabbccdd',
           is_test: false,
           publication_state: Databank::PublicationState::RELEASED,
           release_date: Date.yesterday)
  end

  let(:tally) do
    create(:dataset_download_tally,
           dataset_key: dataset.key,
           doi: '10.13012/B2IDB-aabbccdd_V1',
           tally: 5)
  end

  describe '#should_be_public?' do
    context 'when all conditions are met' do
      it 'returns true' do
        expect(tally.should_be_public?).to be true
      end
    end

    context 'when doi is empty' do
      it 'returns false' do
        tally.doi = ''
        expect(tally.should_be_public?).to be false
      end
    end

    context 'when dataset does not exist' do
      it 'returns false' do
        bad_tally = build(:dataset_download_tally, dataset_key: 'TESTIDB-nonexistent', doi: '10.13012/B2IDB-nonexistent_V1')
        expect(bad_tally.should_be_public?).to be false
      end
    end

    context 'when dataset is a test dataset' do
      let(:test_dataset) { create(:dataset, key: 'TESTIDB-testonly', is_test: true) }

      it 'returns false' do
        test_tally = create(:dataset_download_tally, dataset_key: test_dataset.key, doi: '10.13012/B2IDB-testonly_V1')
        expect(test_tally.should_be_public?).to be false
      end
    end

    context 'when dataset has no release_datetime' do
      let(:draft_dataset) do
        create(:dataset, key: 'TESTIDB-nodraft', is_test: false, publication_state: Databank::PublicationState::DRAFT)
      end

      it 'returns false' do
        draft_tally = create(:dataset_download_tally, dataset_key: draft_dataset.key, doi: '10.13012/B2IDB-nodraft_V1')
        expect(draft_tally.should_be_public?).to be false
      end
    end
  end

  describe '.total_downloads' do
    it 'sums all tally values for a dataset_key' do
      dataset # ensure dataset is created
      create(:dataset_download_tally, dataset_key: dataset.key, doi: '10.13012/B2IDB-aabbccdd_V1', tally: 3)
      create(:dataset_download_tally, dataset_key: dataset.key, doi: '10.13012/B2IDB-aabbccdd_V1', tally: 7)
      expect(DatasetDownloadTally.total_downloads(dataset.key)).to eq(10)
    end

    it 'returns 0 when no records exist for a key' do
      expect(DatasetDownloadTally.total_downloads('TESTIDB-missing')).to eq(0)
    end
  end

  describe '.ip_downloaded_dataset_today' do
    it 'returns false when no downloads from that IP today' do
      expect(DatasetDownloadTally.ip_downloaded_dataset_today(dataset.key, '1.2.3.4')).to be false
    end
  end

  describe '.public_tallies' do
    it 'returns only tallies that should be public' do
      tally # create a valid public tally
      draft_dataset = create(:dataset, key: 'TESTIDB-priv', is_test: false, publication_state: Databank::PublicationState::DRAFT)
      create(:dataset_download_tally, dataset_key: draft_dataset.key, doi: '10.13012/B2IDB-priv_V1')
      public_keys = DatasetDownloadTally.public_tallies.map(&:dataset_key)
      expect(public_keys).to include(dataset.key)
      expect(public_keys).not_to include(draft_dataset.key)
    end
  end

  describe '.public_tally_count_by_dataset_key' do
    it 'returns a hash of dataset_key to total tally count' do
      create(:dataset_download_tally, dataset_key: dataset.key, doi: '10.13012/B2IDB-aabbccdd_V1', tally: 4)
      create(:dataset_download_tally, dataset_key: dataset.key, doi: '10.13012/B2IDB-aabbccdd_V1', tally: 6)
      result = DatasetDownloadTally.public_tally_count_by_dataset_key
      expect(result[dataset.key]).to eq(10)
    end
  end

  describe '.dataset_download_tallies' do
    it 'returns records for the given dataset_key' do
      tally
      other_dataset = create(:dataset, key: 'TESTIDB-otherds')
      other_tally = create(:dataset_download_tally, dataset_key: other_dataset.key, doi: '10.13012/B2IDB-other_V1')
      result = DatasetDownloadTally.dataset_download_tallies(dataset.key)
      expect(result).to include(tally)
      expect(result).not_to include(other_tally)
    end
  end
end
