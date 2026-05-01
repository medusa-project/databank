require 'rails_helper'

RSpec.describe Dataset::MessageText, type: :model do
  let(:dataset) do
    create(
      :dataset,
      key: 'TESTIDB-7654321',
      identifier: '10.13012/B2IDB-7654321_V1',
      publication_state: Databank::PublicationState::DRAFT,
      release_date: Date.current + 7,
      embargo: Databank::PublicationState::Embargo::NONE
    )
  end

  describe '#availability_statement' do
    it 'returns embargoed statement when dataset is embargoed with valid date' do
      allow(dataset).to receive(:embargoed_with_valid_date?).and_return(true)

      message = dataset.availability_statement

      expect(message).to include('will be openly available')
      expect(message).to include(dataset.persistent_url)
      expect(message).to include(dataset.release_date.to_s)
    end

    it 'returns openly available statement when publication state is released' do
      allow(dataset).to receive(:embargoed_with_valid_date?).and_return(false)
      dataset.publication_state = Databank::PublicationState::RELEASED

      message = dataset.availability_statement

      expect(message).to include('is openly available')
      expect(message).to include(dataset.persistent_url)
    end

    it 'returns private statement when not released and not embargoed' do
      allow(dataset).to receive(:embargoed_with_valid_date?).and_return(false)
      dataset.publication_state = Databank::PublicationState::DRAFT

      expect(dataset.availability_statement).to eq('This dataset is not publicly available.')
    end
  end

  describe '.embargoed_with_valid_date' do
    it 'returns true for future date and valid embargo code' do
      dataset.release_date = Date.current + 3
      dataset.embargo = Databank::PublicationState::Embargo::FILE

      expect(Dataset.embargoed_with_valid_date(dataset: dataset)).to be true
    end

    it 'returns nil when release date is missing' do
      dataset.release_date = nil
      dataset.embargo = Databank::PublicationState::Embargo::FILE

      expect(Dataset.embargoed_with_valid_date(dataset: dataset)).to be_nil
    end

    it 'returns false when embargo code is not in embargo array' do
      dataset.release_date = Date.current + 3
      dataset.embargo = Databank::PublicationState::Embargo::NONE

      expect(Dataset.embargoed_with_valid_date(dataset: dataset)).to be false
    end
  end

  describe '.deposit_confirmation_notice' do
    it 'returns released message for old draft transitioning to released' do
      dataset.publication_state = Databank::PublicationState::RELEASED

      message = Dataset.deposit_confirmation_notice(Databank::PublicationState::DRAFT, dataset)

      expect(message).to include('Dataset was successfully published')
      expect(message).to include(dataset.identifier)
      expect(message).to include(dataset.persistent_url)
    end

    it 'returns review message for versioned record returning to draft' do
      dataset.publication_state = Databank::PublicationState::DRAFT

      message = Dataset.deposit_confirmation_notice(Databank::PublicationState::TempSuppress::VERSION, dataset)

      expect(message).to include('awaiting curator review')
    end

    it 'returns fallback message for unexpected old state' do
      dataset.publication_state = Databank::PublicationState::RELEASED

      message = Dataset.deposit_confirmation_notice('unexpected-old-state', dataset)

      expect(message).to include("Changes to this dataset's <strong>public</strong> record have been made effective.")
    end
  end

  describe '.publish_modal_msg' do
    it 'raises when dataset is nil' do
      expect { Dataset.publish_modal_msg(dataset: nil) }.to raise_error(RuntimeError, /no dataset passed/)
    end

    it 'builds file-embargo message for draft dataset with valid embargo settings' do
      dataset.publication_state = Databank::PublicationState::DRAFT
      dataset.embargo = Databank::PublicationState::Embargo::FILE
      dataset.release_date = Date.current + 10

      message = Dataset.publish_modal_msg(dataset: dataset)

      expect(message).to include('record <strong>public</strong>')
      expect(message).to include('files will remain unavailable')
      expect(message).to include(dataset.release_date.iso8601)
      expect(message).to include('All authors will receive a confirmation email')
    end

    it 'builds metadata-embargo warning when released dataset is changed to metadata embargo' do
      dataset.publication_state = Databank::PublicationState::RELEASED
      dataset.embargo = Databank::PublicationState::Embargo::METADATA
      dataset.release_date = Date.current + 10

      message = Dataset.publish_modal_msg(dataset: dataset)

      expect(message).to include('remove the dataset from <strong>public</strong> availability')
      expect(message).to include(dataset.release_date.iso8601)
    end

    it 'builds non-embargo public message for draft datasets' do
      dataset.publication_state = Databank::PublicationState::DRAFT
      dataset.embargo = Databank::PublicationState::Embargo::NONE

      message = Dataset.publish_modal_msg(dataset: dataset)

      expect(message).to include('make the dataset <strong>public</strong>')
      expect(message).to include('data files will be <strong>publicly</strong> available')
    end
  end
end
