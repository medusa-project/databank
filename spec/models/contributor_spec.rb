# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Contributor, type: :model do
  let(:dataset) { create(:dataset) }

  describe 'associations' do
    it 'belongs to a dataset' do
      contributor = create(:contributor, dataset: dataset)
      expect(contributor.dataset).to eq(dataset)
    end
  end

  describe '#display_name' do
    context 'when type_of is PERSON' do
      it 'returns "given_name family_name"' do
        contributor = build(:contributor, given_name: 'Jane', family_name: 'Doe', type_of: Databank::CreatorType::PERSON)
        expect(contributor.display_name).to eq('Jane Doe')
      end

      it 'handles nil given_name gracefully' do
        contributor = build(:contributor, given_name: nil, family_name: 'Doe', type_of: Databank::CreatorType::PERSON)
        expect(contributor.display_name).to eq(' Doe')
      end

      it 'handles nil family_name gracefully' do
        contributor = build(:contributor, given_name: 'Jane', family_name: nil, type_of: Databank::CreatorType::PERSON)
        expect(contributor.display_name).to eq('Jane ')
      end
    end

    context 'when type_of is INSTITUTION' do
      it 'returns institution_name' do
        contributor = build(:contributor, :institution, institution_name: 'UIUC Library')
        expect(contributor.display_name).to eq('UIUC Library')
      end

      it 'returns empty string when institution_name is nil' do
        contributor = build(:contributor, :institution, institution_name: nil)
        expect(contributor.display_name).to eq('')
      end
    end
  end

  describe '#list_name' do
    context 'when type_of is PERSON' do
      it 'returns "family_name, given_name"' do
        contributor = build(:contributor, given_name: 'Jane', family_name: 'Doe', type_of: Databank::CreatorType::PERSON)
        expect(contributor.list_name).to eq('Doe, Jane')
      end

      it 'handles nil family_name gracefully' do
        contributor = build(:contributor, given_name: 'Jane', family_name: nil, type_of: Databank::CreatorType::PERSON)
        expect(contributor.list_name).to eq(', Jane')
      end

      it 'handles nil given_name gracefully' do
        contributor = build(:contributor, given_name: nil, family_name: 'Doe', type_of: Databank::CreatorType::PERSON)
        expect(contributor.list_name).to eq('Doe, ')
      end
    end

    context 'when type_of is INSTITUTION' do
      it 'returns institution_name' do
        contributor = build(:contributor, :institution, institution_name: 'Campus Office')
        expect(contributor.list_name).to eq('Campus Office')
      end
    end
  end

  describe 'default_scope' do
    it 'orders contributors by row_position' do
      c2 = create(:contributor, dataset: dataset, row_position: 2)
      c1 = create(:contributor, dataset: dataset, row_position: 1)
      expect(dataset.contributors.first).to eq(c1)
      expect(dataset.contributors.second).to eq(c2)
    end
  end

  describe '#set_dataset_nested_updated_at' do
    it 'updates dataset nested_updated_at on create' do
      before_time = Time.now.utc - 1.second
      create(:contributor, dataset: dataset)
      dataset.reload
      expect(dataset.nested_updated_at).to be > before_time
    end

    it 'updates dataset nested_updated_at on update' do
      contributor = create(:contributor, dataset: dataset)
      before_time = Time.now.utc
      contributor.update!(given_name: 'Updated')
      dataset.reload
      expect(dataset.nested_updated_at).to be >= before_time
    end
  end
end
