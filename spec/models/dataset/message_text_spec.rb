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

    it 'returns false when release date is in the past' do
      dataset.release_date = Date.current - 1
      dataset.embargo = Databank::PublicationState::Embargo::METADATA

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

    it 'returns placeholder message for released to metadata embargo transition' do
      dataset.publication_state = Databank::PublicationState::Embargo::METADATA

      message = Dataset.deposit_confirmation_notice(Databank::PublicationState::RELEASED, dataset)

      expect(message).to include('Placeholder metadata has replaced previously published metadata')
      expect(message).to include(dataset.identifier)
      expect(message).to include(dataset.persistent_url)
    end

    it 'returns embargo file publication message for draft to file embargo transition' do
      dataset.publication_state = Databank::PublicationState::Embargo::FILE

      message = Dataset.deposit_confirmation_notice(Databank::PublicationState::DRAFT, dataset)

      expect(message).to include('Dataset record was successfully published')
      expect(message).to include(dataset.release_date.iso8601)
    end

    it 'warns and returns unexpected error for unknown new state from released' do
      dataset.publication_state = 'weird-new-state'
      allow(Rails.logger).to receive(:warn)

      message = Dataset.deposit_confirmation_notice(Databank::PublicationState::RELEASED, dataset)

      expect(message).to include('Unexpected error')
      expect(Rails.logger).to have_received(:warn).with(/UE2 - key:/)
    end

    it 'returns no changes message for metadata embargo staying metadata embargo' do
      dataset.publication_state = Databank::PublicationState::Embargo::METADATA

      message = Dataset.deposit_confirmation_notice(Databank::PublicationState::Embargo::METADATA, dataset)

      expect(message).to include('No changes have been published')
      expect(message).to include(dataset.persistent_url)
    end

    it 'returns publicly available message for file embargo to released transition' do
      dataset.publication_state = Databank::PublicationState::RELEASED

      message = Dataset.deposit_confirmation_notice(Databank::PublicationState::Embargo::FILE, dataset)

      expect(message).to include('files are publically available')
    end

    it 'returns metadata placeholder message for permanently suppressed file to metadata embargo' do
      dataset.publication_state = Databank::PublicationState::Embargo::METADATA

      message = Dataset.deposit_confirmation_notice(Databank::PublicationState::PermSuppress::FILE, dataset)

      expect(message).to include('descriptive record for your dataset and your files will be <strong>publicly</strong> available')
      expect(message).to include(dataset.release_date.iso8601)
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

    it 'builds metadata-embargo save message when metadata embargo remains in effect' do
      dataset.publication_state = Databank::PublicationState::Embargo::METADATA
      dataset.embargo = Databank::PublicationState::Embargo::METADATA
      dataset.release_date = Date.current + 10

      message = Dataset.publish_modal_msg(dataset: dataset)

      expect(message).to include('save the metadata changes')
      expect(message).to include(dataset.identifier)
      expect(message).to include(dataset.release_date.iso8601)
    end

    it 'builds DOI reservation message for draft dataset with metadata embargo' do
      dataset.publication_state = Databank::PublicationState::DRAFT
      dataset.embargo = Databank::PublicationState::Embargo::METADATA
      dataset.release_date = Date.current + 5

      message = Dataset.publish_modal_msg(dataset: dataset)

      expect(message).to include('This action will reserve a DOI')
      expect(message).to include("DOI link will fail until #{dataset.release_date.iso8601}")
      expect(message).to include('All authors will receive a confirmation email')
    end

    it 'builds non-embargo public message for draft datasets' do
      dataset.publication_state = Databank::PublicationState::DRAFT
      dataset.embargo = Databank::PublicationState::Embargo::NONE

      message = Dataset.publish_modal_msg(dataset: dataset)

      expect(message).to include('make the dataset <strong>public</strong>')
      expect(message).to include('data files will be <strong>publicly</strong> available')
    end

    it 'builds public update message for non-draft non-embargo datasets' do
      dataset.publication_state = Databank::PublicationState::RELEASED
      dataset.embargo = Databank::PublicationState::Embargo::NONE

      message = Dataset.publish_modal_msg(dataset: dataset)

      expect(message).to include('make your updates to the dataset record <strong>public</strong>')
      expect(message).not_to include('All authors will receive a confirmation email')
    end
  end
end
