require 'rails_helper'

RSpec.describe DatasetSuppressionService do
  let(:dataset) { create(:dataset) }
  let(:service) { described_class.new(dataset) }

  describe '#temporarily_suppress_metadata' do
    it 'persists the hold state and reports DataCite update failure' do
      allow(dataset).to receive(:update_doi).and_return(false)

      result = service.temporarily_suppress_metadata

      expect(result.saved).to be(true)
      expect(result.doi_updated).to be(false)
      expect(dataset.reload.hold_state).to eq(Databank::PublicationState::TempSuppress::METADATA)
    end
  end

  describe '#permanently_suppress_files' do
    it 'persists permanent suppression and reports Globus failures' do
      allow(dataset).to receive(:remove_from_globus_download).and_raise(IOError, 'Globus unavailable')
      allow(Rails.logger).to receive(:error)

      result = service.permanently_suppress_files

      expect(result).to be_integration_failed
      expect(dataset.reload.publication_state).to eq(Databank::PublicationState::PermSuppress::FILE)
      expect(dataset.hold_state).to eq(Databank::PublicationState::PermSuppress::FILE)
      expect(Rails.logger).to have_received(:error).with(/Globus unavailable/)
    end
  end

  describe '#unsuppress_review' do
    it 'sends approval only after the state is saved' do
      expect(dataset).to receive(:send_approve_version)

      result = service.unsuppress_review

      expect(result.saved).to be(true)
      expect(dataset.reload.hold_state).to eq(Databank::PublicationState::TempSuppress::NONE)
    end

    it 'does not send approval when saving fails' do
      allow(dataset).to receive(:save).and_return(false)
      expect(dataset).not_to receive(:send_approve_version)

      result = service.unsuppress_review

      expect(result.saved).to be(false)
    end
  end
end
