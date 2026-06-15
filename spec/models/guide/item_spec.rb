require 'rails_helper'

RSpec.describe Guide::Item, type: :model do
  let(:section) { FactoryBot.create(:guide_section) }
  let(:item) { FactoryBot.create(:guide_item, section_id: section.id) }
  let(:subitem) { FactoryBot.create(:guide_subitem, item_id: item.id) }

  describe 'associations' do
    it 'belongs to a guide section' do
      expect(item).to belong_to(:guide_section).optional
    end

    it 'has many guide subitems' do
      expect(item).to have_many(:guide_subitems)
    end
  end

  describe '#has_children?' do
    it 'returns true when item has subitems' do
      subitem
      expect(item.has_children?).to be true
    end

    it 'returns false when item has no subitems' do
      expect(item.has_children?).to be false
    end
  end

  describe '#has_public_children?' do
    it 'returns true when item has public subitems' do
      FactoryBot.create(:guide_subitem, item_id: item.id, public: true)
      expect(item.has_public_children?).to be true
    end

    it 'returns false when all subitems are private' do
      FactoryBot.create(:guide_subitem, item_id: item.id, public: false)
      expect(item.has_public_children?).to be false
    end

    it 'returns false when item has no subitems' do
      expect(item.has_public_children?).to be false
    end
  end

  describe '#ordered_children' do
    it 'returns subitems ordered by ordinal' do
      subitem1 = FactoryBot.create(:guide_subitem, item_id: item.id, ordinal: 2)
      subitem2 = FactoryBot.create(:guide_subitem, item_id: item.id, ordinal: 1)
      subitem3 = FactoryBot.create(:guide_subitem, item_id: item.id, ordinal: 3)

      expect(item.ordered_children).to eq([subitem2, subitem1, subitem3])
    end

    it 'returns empty array when item has no subitems' do
      expect(item.ordered_children).to be_empty
    end
  end

  describe '#parent' do
    it 'returns the parent section' do
      expect(item.parent).to eq(section)
    end

    it 'returns nil when no section_id is set' do
      orphan_item = FactoryBot.create(:guide_item, section_id: nil)
      expect(orphan_item.parent).to be_nil
    end

    it 'returns nil when section does not exist' do
      item_with_missing_section = FactoryBot.create(:guide_item, section_id: 99999)
      expect(item_with_missing_section.parent).to be_nil
    end
  end
end
