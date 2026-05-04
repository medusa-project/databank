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

    context 'when approved version candidate is temp-suppressed version on no hold' do
      it 'returns true' do
        dataset.identifier = 'doi:10.1234/5678'
        dataset.publication_state = Databank::PublicationState::TempSuppress::VERSION
        dataset.hold_state = Databank::PublicationState::TempSuppress::NONE

        expect(dataset.ok_to_publish?).to be true
      end
    end

    context 'when dataset is released and otherwise valid' do
      it 'returns false' do
        dataset.identifier = 'doi:10.1234/5678'
        dataset.publication_state = Databank::PublicationState::RELEASED
        dataset.hold_state = Databank::PublicationState::TempSuppress::NONE

        expect(dataset.ok_to_publish?).to be false
      end
    end
  end

  describe '#local_mode?' do
    it 'returns true when local mode is enabled' do
      allow(IDB_CONFIG).to receive(:[]).with(:local_mode).and_return(true)

      expect(dataset.local_mode?).to be true
    end

    it 'returns false when local mode is disabled' do
      allow(IDB_CONFIG).to receive(:[]).with(:local_mode).and_return(false)

      expect(dataset.local_mode?).to be false
    end
  end

  describe '#send_publication_notice' do
    it 'returns true when confirmation mail sends successfully' do
      notification = double
      allow(notification).to receive(:deliver_now)
      allow(DatabankMailer).to receive(:confirm_deposit).with(dataset.key).and_return(notification)

      expect(dataset.send_publication_notice).to be true
    end

    it 'returns false and sends fallback notice when confirm_deposit fails' do
      allow(DatabankMailer).to receive(:confirm_deposit).and_raise(StandardError.new('mailer failure'))
      fallback = double
      allow(fallback).to receive(:deliver_now)
      expect(DatabankMailer).to receive(:confirmation_not_sent).with(dataset.key, instance_of(StandardError)).and_return(fallback)

      expect(dataset.send_publication_notice).to be false
    end
  end

  describe '#publish' do
    context 'when dataset is permanently suppressed' do
      it 'raises an error' do
        dataset.publication_state = Databank::PublicationState::PermSuppress::METADATA

        expect { dataset.publish(user) }.to raise_error(/Cannot publish permanently suppressed dataset/)
      end
    end

    context 'when dataset has incomplete uploads' do
      it 'returns an incomplete-upload error hash' do
        allow(dataset).to receive(:incomplete_datafiles).and_return([double])

        result = dataset.publish(user)

        expect(result[:status]).to eq('error')
        expect(result[:error_text]).to include('Incomplete datafile upload(s) found')
      end
    end

    context 'when the dataset is not ok to publish' do
      it 'returns an error status' do
        allow(dataset).to receive(:incomplete_datafiles).and_return([])
        allow(dataset).to receive(:ok_to_publish?).and_return(false)
        result = dataset.publish(user)
        expect(result[:status]).to eq("error")
        expect(result[:error_text]).to eq("Dataset is not ok to publish")
      end
    end

    context 'when completion check fails' do
      it 'returns error hash from completion check' do
        allow(dataset).to receive(:incomplete_datafiles).and_return([])
        allow(dataset).to receive(:ok_to_publish?).and_return(true)
        allow(Dataset).to receive(:completion_check).and_return('missing title')

        result = dataset.publish(user)

        expect(result).to eq(status: 'error', error_text: 'missing title')
      end
    end

    context 'when the dataset is ok to publish' do
      before do
        allow(dataset).to receive(:incomplete_datafiles).and_return([])
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

      it 'returns an error when initial save fails' do
        allow(dataset).to receive(:save!).and_raise(StandardError.new('save failed'))

        result = dataset.publish(user)

        expect(result).to eq(status: 'error', error_text: 'Failed to publish dataset')
      end

      it 'uses register_doi for non-public metadata' do
        allow(dataset).to receive(:metadata_public?).and_return(false)
        expect(dataset).to receive(:register_doi).and_return({status: 'ok'})
        expect(dataset).not_to receive(:publish_doi)

        result = dataset.publish(user)

        expect(result[:status]).to eq('ok')
      end

      it 'returns local-mode success hash without sending publication notice' do
        allow(dataset).to receive(:local_mode?).and_return(true)
        expect(dataset).not_to receive(:send_publication_notice)

        result = dataset.publish(user)

        expect(result[:status]).to eq(:ok)
      end

      it 'returns error when publication notice is not sent' do
        allow(dataset).to receive(:send_publication_notice).and_return(false)

        result = dataset.publish(user)

        expect(result).to eq(status: :error, message: 'publication notice not sent')
      end

      it 'destroys share code when publication state is released' do
        share_code = double
        expect(share_code).to receive(:destroy)
        allow(dataset).to receive(:share_code).and_return(share_code)
        dataset.embargo = nil

        dataset.publish(user)
      end

      it 'indexes previous dataset when present' do
        previous = double
        expect(Sunspot).to receive(:index!).with([previous])
        allow(dataset).to receive(:previous_idb_dataset).and_return(previous)

        dataset.publish(user)
      end

      it 'returns invalid-state error when revert save fails after DOI failure' do
        allow(dataset).to receive(:publish_doi).and_return({status: 'error'})
        call_count = 0
        allow(dataset).to receive(:save!) do
          call_count += 1
          raise StandardError.new('revert failed') if call_count == 2

          true
        end

        result = dataset.publish(user)

        expect(result[:status]).to eq('error')
        expect(result[:error_text]).to include('in invalid state')
      end
    end
  end

  describe 'review request helpers' do
    it 'has_review_request? delegates to ReviewRequest.exists?' do
      expect(ReviewRequest).to receive(:exists?).with(dataset_key: dataset.key).and_return(true)

      expect(dataset.has_review_request?).to be true
    end

    it 'review_requests delegates to ReviewRequest.where' do
      relation = double
      expect(ReviewRequest).to receive(:where).with(dataset_key: dataset.key).and_return(relation)

      expect(dataset.review_requests).to eq(relation)
    end

    it 'destroy_review_requests destroys all linked requests' do
      relation = double
      expect(dataset).to receive(:review_requests).and_return(relation)
      expect(relation).to receive(:destroy_all)

      dataset.destroy_review_requests
    end
  end

  describe '#destroy_incomplete_uploads' do
    it 'returns true when there are no invalid web ids' do
      relation = double
      allow(dataset).to receive(:datafiles).and_return(relation)
      allow(relation).to receive(:pluck).with(:web_id).and_return(['abc123'])

      expect(dataset.destroy_incomplete_uploads).to be true
    end

    it 'destroys rows for invalid web ids when detected' do
      relation = double
      bad_rows = double
      allow(dataset).to receive(:datafiles).and_return(relation)
      allow(relation).to receive(:pluck).with(:web_id).and_return(['abc123', nil], ['abc123'])
      expect(relation).to receive(:where).with(web_id: [nil]).and_return(bad_rows)
      expect(bad_rows).to receive(:destroy_all)

      dataset.destroy_incomplete_uploads
    end
  end

  describe '#show_publish_only?' do
    it 'returns true only when all review and completion checks pass' do
      allow(dataset).to receive(:in_pre_publication_review?).and_return(true)
      dataset.hold_state = Databank::PublicationState::TempSuppress::NONE
      allow(Dataset).to receive(:completion_check).with(dataset).and_return('ok')

      expect(dataset.show_publish_only?).to be true
    end

    it 'returns false when not in pre-publication review' do
      allow(dataset).to receive(:in_pre_publication_review?).and_return(false)

      expect(dataset.show_publish_only?).to be false
    end

    it 'returns false when completion check fails' do
      allow(dataset).to receive(:in_pre_publication_review?).and_return(true)
      dataset.hold_state = Databank::PublicationState::TempSuppress::NONE
      allow(Dataset).to receive(:completion_check).with(dataset).and_return('missing files')

      expect(dataset.show_publish_only?).to be false
    end
  end
end
