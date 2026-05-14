# frozen_string_literal: true

require 'rails_helper'
require 'cancan/matchers'

RSpec.describe Ability, type: :model do
  subject(:ability) { Ability.new(user) }

  let(:dataset) { create(:dataset, depositor_email: 'owner@illinois.edu', publication_state: Databank::PublicationState::DRAFT) }

  describe 'admin user' do
    let(:user) { create(:user, role: 'admin') }

    it 'can manage everything' do
      expect(ability).to be_able_to(:manage, :all)
    end

    it 'can manage datasets' do
      expect(ability).to be_able_to(:manage, dataset)
    end
  end

  describe 'depositor user' do
    let(:user) { create(:user, role: 'depositor') }

    it 'can create Dataset' do
      expect(ability).to be_able_to(:create, Dataset)
    end

    it 'can create Datafile' do
      expect(ability).to be_able_to(:create, Datafile)
    end

    it 'cannot manage all' do
      expect(ability).not_to be_able_to(:manage, :all)
    end
  end

  describe 'guest user' do
    let(:user) { create(:user, role: 'guest') }

    it 'cannot create Dataset' do
      expect(ability).not_to be_able_to(:create, Dataset)
    end
  end

  describe 'nil user (unauthenticated)' do
    let(:user) { nil }

    it 'cannot create Dataset' do
      expect(ability).not_to be_able_to(:create, Dataset)
    end
  end

  describe ':view_version_acknowledgement on Dataset' do
    let(:dataset) do
      create(:dataset,
             depositor_email: 'owner@illinois.edu',
             hold_state: Databank::PublicationState::TempSuppress::VERSION)
    end

    context 'when user is the depositor' do
      let(:user) { create(:user, email: 'owner@illinois.edu', role: 'depositor') }

      it 'can view_version_acknowledgement' do
        expect(ability).to be_able_to(:view_version_acknowledgement, dataset)
      end
    end

    context 'when user is not the depositor and has no special ability' do
      let(:user) { create(:user, email: 'other@illinois.edu', role: 'depositor') }

      it 'cannot view_version_acknowledgement' do
        expect(ability).not_to be_able_to(:view_version_acknowledgement, dataset)
      end
    end

    context 'when the hold_state is not VERSION' do
      let(:other_dataset) do
        create(:dataset,
               depositor_email: 'owner@illinois.edu',
               hold_state: Databank::PublicationState::TempSuppress::NONE)
      end
      let(:user) { create(:user, email: 'owner@illinois.edu', role: 'depositor') }

      it 'cannot view_version_acknowledgement' do
        expect(ability).not_to be_able_to(:view_version_acknowledgement, other_dataset)
      end
    end
  end

  describe ':read on Dataset' do
    context 'when metadata is public' do
      let(:dataset) do
        create(:dataset,
               depositor_email: 'owner@illinois.edu',
               publication_state: Databank::PublicationState::RELEASED,
               hold_state: Databank::PublicationState::TempSuppress::NONE)
      end
      let(:user) { create(:user, email: 'stranger@illinois.edu', role: 'depositor') }

      it 'can read the dataset' do
        expect(ability).to be_able_to(:read, dataset)
      end
    end

    context 'when dataset is under VERSION hold' do
      let(:dataset) do
        create(:dataset,
               depositor_email: 'owner@illinois.edu',
               publication_state: Databank::PublicationState::DRAFT,
               hold_state: Databank::PublicationState::TempSuppress::VERSION)
      end
      let(:user) { create(:user, email: 'stranger@illinois.edu', role: 'depositor') }

      it 'cannot read the dataset' do
        expect(ability).not_to be_able_to(:read, dataset)
      end
    end

    context 'when user is the depositor' do
      let(:user) { create(:user, email: 'owner@illinois.edu', role: 'depositor') }

      it 'can read own draft dataset' do
        expect(ability).to be_able_to(:read, dataset)
      end
    end
  end

  describe ':update on Dataset' do
    context 'when user is the depositor' do
      let(:user) { create(:user, email: 'owner@illinois.edu', role: 'depositor') }

      it 'can update own dataset' do
        expect(ability).to be_able_to(:update, dataset)
      end
    end

    context 'when user is not the depositor' do
      let(:user) { create(:user, email: 'other@illinois.edu', role: 'depositor') }

      it 'cannot update another user dataset' do
        expect(ability).not_to be_able_to(:update, dataset)
      end
    end
  end

  describe ':destroy on Dataset' do
    context 'when dataset is draft and user is depositor' do
      let(:user) { create(:user, email: 'owner@illinois.edu', role: 'depositor') }

      it 'can destroy the dataset' do
        expect(ability).to be_able_to(:destroy, dataset)
      end
    end

    context 'when dataset is released' do
      let(:published_dataset) do
        create(:dataset,
               depositor_email: 'owner@illinois.edu',
               publication_state: Databank::PublicationState::RELEASED)
      end
      let(:user) { create(:user, email: 'owner@illinois.edu', role: 'depositor') }

      it 'cannot destroy a released dataset' do
        expect(ability).not_to be_able_to(:destroy, published_dataset)
      end
    end

    context 'when user is not the depositor' do
      let(:user) { create(:user, email: 'other@illinois.edu', role: 'depositor') }

      it 'cannot destroy another user dataset' do
        expect(ability).not_to be_able_to(:destroy, dataset)
      end
    end
  end

  describe ':view_files on Dataset' do
    context 'when files are public' do
      let(:dataset) do
        create(:dataset,
               depositor_email: 'owner@illinois.edu',
               publication_state: Databank::PublicationState::RELEASED,
               hold_state: Databank::PublicationState::TempSuppress::NONE)
      end
      let(:user) { create(:user, email: 'stranger@illinois.edu', role: 'depositor') }

      it 'can view_files' do
        expect(ability).to be_able_to(:view_files, dataset)
      end
    end

    context 'when user is the depositor' do
      let(:user) { create(:user, email: 'owner@illinois.edu', role: 'depositor') }

      it 'can view_files of own dataset' do
        expect(ability).to be_able_to(:view_files, dataset)
      end
    end

    context 'when user has no access to a private dataset' do
      let(:user) { create(:user, email: 'other@illinois.edu', role: 'depositor') }

      it 'cannot view_files' do
        expect(ability).not_to be_able_to(:view_files, dataset)
      end
    end
  end
end
