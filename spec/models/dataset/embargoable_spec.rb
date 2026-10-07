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
    it 'adds the one-month embargo notice to the ticket and notifies the depositor' do
      dataset.update!(
        depositor_email: 'depositor@example.org',
        release_date: Date.new(2026, 2, 3)
      )
      allow(dataset).to receive(:ingest_datetime).and_return(Time.zone.parse('2025-01-02T03:04:05Z'))
      expect(dataset).to receive(:add_comment).with(
        change: a_string_including(
          '2025-01-02',
          '2026-02-03',
          'coming up in one month',
          'maximum amount of time a dataset may be embargoed is one year',
          "/datasets/#{dataset.key}/edit"
        ),
        notify: ['depositor@example.org']
      )

      dataset.send_embargo_approaching_1m
    end
  end

  describe '#send_embargo_approaching_1w' do
    it 'adds the one-week embargo notice to the ticket and notifies the depositor' do
      dataset.update!(
        depositor_email: 'depositor@example.org',
        release_date: Date.new(2026, 2, 3)
      )
      allow(dataset).to receive(:ingest_datetime).and_return(Time.zone.parse('2025-01-02T03:04:05Z'))
      expect(dataset).to receive(:add_comment).with(
        change: a_string_including(
          '2025-01-02',
          '2026-02-03',
          'coming up in one week',
          'maximum amount of time a dataset may be embargoed is one year',
          "/datasets/#{dataset.key}/edit"
        ),
        notify: ['depositor@example.org']
      )

      dataset.send_embargo_approaching_1w
    end
  end
end