require 'rails_helper'

RSpec.describe Dataset::Publishable, type: :model do
  fixtures :users, :datasets, :datafiles

  let(:user) { users(:researcher1) }
  let(:dataset) { datasets(:draft1) }
  let(:datafile) { datafiles(:datafile1) }

  describe '#ok_to_publish?' do
    context 'when the dataset is in draft state' do
      it 'returns true' do
        dataset.publication_state = Databank::PublicationState::DRAFT
        expect(dataset.ok_to_publish?).to be true
      end
    end

    context 'when the dataset has a metadata-only embargo' do
      it 'returns true' do
        dataset.identifier = 'doi:10.1234/5678'
        dataset.publication_state = Databank::PublicationState::Embargo::METADATA
        dataset.embargo = Databank::PublicationState::Embargo::METADATA
        dataset.hold_state = Databank::PublicationState::TempSuppress::NONE
        expect(dataset.ok_to_publish?).to be true
      end
    end

    context 'when the dataset has a file embargo' do
      it 'returns true' do
        dataset.identifier = 'doi:10.1234/5678'
        dataset.publication_state = Databank::PublicationState::Embargo::FILE
        dataset.embargo = Databank::PublicationState::Embargo::FILE
        expect(dataset.ok_to_publish?).to be true
      end
    end

    context 'when the dataset is not a draft and has no identifier' do
      it 'returns false' do
        dataset.publication_state = Databank::PublicationState::Embargo::FILE
        dataset.identifier = nil
        expect(dataset.ok_to_publish?).to be false
      end
    end

    context 'when the dataset is in a hold state' do
      it 'returns false' do
        dataset.publication_state = Databank::PublicationState::DRAFT
        dataset.hold_state = Databank::PublicationState::TempSuppress::METADATA
        dataset.embargo = Databank::PublicationState::Embargo::FILE
        dataset.identifier = 'doi:10.1234/5678'
        expect(dataset.ok_to_publish?).to be false
      end
    end
  end

  describe '#publish' do
    context 'when the dataset is not ok to publish' do
      it 'returns an error status' do
        allow(dataset).to receive(:ok_to_publish?).and_return(false)
        result = dataset.publish(user)
        expect(result[:status]).to eq("error")
        expect(result[:error_text]).to eq("Dataset is not ok to publish")
      end
    end

    context 'when the dataset is ok to publish' do
      before do
        allow(dataset).to receive(:ok_to_publish?).and_return(true)
        allow(dataset).to receive(:destroy_incomplete_uploads)
        allow(Dataset).to receive(:completion_check).and_return("ok")
        allow(dataset).to receive(:save!).and_return(true)
        allow(dataset).to receive(:publish_doi).and_return({status: "ok"})
        allow(dataset).to receive(:register_doi).and_return({status: "ok"})
        allow(MedusaIngest).to receive(:send_dataset_to_medusa)
        allow(Sunspot).to receive(:index!)
        allow(dataset).to receive(:send_publication_notice).and_return(true)
      end

      it 'publishes the dataset and returns a success status' do
        result = dataset.publish(user)
        expect(result[:status]).to eq("ok")
      end

      it 'sets the identifier if it is missing' do
        dataset.publication_state = Databank::PublicationState::DRAFT
        dataset.identifier = nil
        allow(dataset).to receive(:default_identifier).and_return("doi:10.1234/5678")
        dataset.publish(user)
        expect(dataset.identifier).to eq("doi:10.1234/5678")
      end

      it 'sets the publication state to the embargo state if embargo is set and valid' do
        dataset.embargo = Databank::PublicationState::Embargo::METADATA
        dataset.publish(user)
        expect(dataset.publication_state).to eq(Databank::PublicationState::Embargo::METADATA)
      end

      it 'sets the publication state to released if embargo is not set or invalid' do
        dataset.embargo = nil
        dataset.publish(user)
        expect(dataset.publication_state).to eq(Databank::PublicationState::RELEASED)
      end

      it 'sets the release date if the publication state was draft and is now released' do
        dataset.publication_state = Databank::PublicationState::DRAFT
        dataset.publish(user)
        expect(dataset.release_date).to eq(Date.current)
      end

      it 'returns an error if the publication state is not valid' do
        allow(Databank::PublicationState::PUB_ARRAY).to receive(:include?).and_return(false)
        result = dataset.publish(user)
        expect(result[:status]).to eq("error")
        expect(result[:error_text]).to eq("problem publishing dataset: #{dataset.key}")
      end

      it 'reverts the publication state and returns an error if DOI publication fails' do
        allow(dataset).to receive(:publish_doi).and_return({status: "error"})
        old_publication_state = dataset.publication_state
        result = dataset.publish(user)
        expect(dataset.publication_state).to eq(old_publication_state)
        expect(result[:status]).to eq("error")
      end
    end
  end
end
