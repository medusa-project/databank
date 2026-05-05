require 'rails_helper'

RSpec.describe Dataset::Embargoable, type: :model do
  let(:dataset) { create(:dataset) }

  describe '#embargoed_with_valid_date?' do
    it 'returns true when embargo is an embargo state and release date is in the future' do
      dataset.embargo = Databank::PublicationState::Embargo::FILE
      dataset.release_date = 2.days.from_now

      expect(dataset.embargoed_with_valid_date?).to be true
    end

    it 'returns false when release date is missing' do
      dataset.embargo = Databank::PublicationState::Embargo::FILE
      dataset.release_date = nil

      expect(dataset.embargoed_with_valid_date?).to be_falsey
    end

    it 'returns false when release date is not in the future' do
      dataset.embargo = Databank::PublicationState::Embargo::METADATA
      dataset.release_date = 1.day.ago

      expect(dataset.embargoed_with_valid_date?).to be false
    end

    it 'returns false when embargo is not an embargo state' do
      dataset.embargo = Databank::PublicationState::Embargo::NONE
      dataset.release_date = 2.days.from_now

      expect(dataset.embargoed_with_valid_date?).to be false
    end
  end

  describe '#embargoed?' do
    it 'returns true for file embargo state' do
      dataset.embargo = Databank::PublicationState::Embargo::FILE

      expect(dataset.embargoed?).to be true
    end

    it 'returns false for none embargo state' do
      dataset.embargo = Databank::PublicationState::Embargo::NONE

      expect(dataset.embargoed?).to be false
    end
  end

  describe '#ensure_embargo' do
    it 'returns true when publication state is draft' do
      dataset.publication_state = Databank::PublicationState::DRAFT

      expect(dataset.ensure_embargo).to be true
    end

    it 'returns true when publication state already matches embargo' do
      dataset.publication_state = Databank::PublicationState::Embargo::FILE
      dataset.embargo = Databank::PublicationState::Embargo::FILE

      expect(dataset.ensure_embargo).to be true
    end

    it 'returns true when embargo is nil' do
      dataset.publication_state = Databank::PublicationState::RELEASED
      dataset.embargo = nil

      expect(dataset.ensure_embargo).to be true
    end

    it 'returns true when embargo is none' do
      dataset.publication_state = Databank::PublicationState::RELEASED
      dataset.embargo = Databank::PublicationState::Embargo::NONE

      expect(dataset.ensure_embargo).to be true
    end

    it 'returns true when release date is not in the future' do
      dataset.publication_state = Databank::PublicationState::RELEASED
      dataset.embargo = Databank::PublicationState::Embargo::METADATA
      dataset.release_date = Time.current

      expect(dataset.ensure_embargo).to be true
    end

    it 'updates publication state to embargo and saves when release date is in the future' do
      dataset.publication_state = Databank::PublicationState::RELEASED
      dataset.embargo = Databank::PublicationState::Embargo::FILE
      dataset.release_date = 2.days.from_now
      expect(dataset).to receive(:save!).once

      dataset.ensure_embargo

      expect(dataset.publication_state).to eq(Databank::PublicationState::Embargo::FILE)
    end
  end

  describe '#send_embargo_approaching_1m' do
    it 'sends the one-month embargo approaching notification' do
      notification = instance_double(ActionMailer::MessageDelivery, deliver_now: true)
      expect(DatabankMailer).to receive(:embargo_approaching_1m).with(dataset.key).and_return(notification)

      dataset.send_embargo_approaching_1m

      expect(notification).to have_received(:deliver_now)
    end
  end

  describe '#send_embargo_approaching_1w' do
    it 'sends the one-week embargo approaching notification' do
      notification = instance_double(ActionMailer::MessageDelivery, deliver_now: true)
      expect(DatabankMailer).to receive(:embargo_approaching_1w).with(dataset.key).and_return(notification)

      dataset.send_embargo_approaching_1w

      expect(notification).to have_received(:deliver_now)
    end
  end
end