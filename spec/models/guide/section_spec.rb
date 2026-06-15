require 'rails_helper'

RSpec.describe Guide::Section, type: :model do
  let(:section) { FactoryBot.create(:guide_section) }
  let(:item) { FactoryBot.create(:guide_item, section_id: section.id) }
  let(:subitem) { FactoryBot.create(:guide_subitem, item_id: item.id) }

  describe 'associations' do
    it 'has many guide items' do
      expect(section).to have_many(:guide_items)
    end

    it 'destroys associated items when destroyed' do
      item
      expect { section.destroy }.to change(Guide::Item, :count).by(-1)
    end
  end

  describe '#has_children?' do
    it 'returns true when section has items' do
      item
      expect(section.has_children?).to be true
    end

    it 'returns false when section has no items' do
      expect(section.has_children?).to be false
    end
  end

  describe '#has_public_children?' do
    it 'returns true when section has public items' do
      FactoryBot.create(:guide_item, section_id: section.id, public: true)
      expect(section.has_public_children?).to be true
    end

    it 'returns false when all items are private' do
      FactoryBot.create(:guide_item, section_id: section.id, public: false)
      expect(section.has_public_children?).to be false
    end

    it 'returns false when section has no items' do
      expect(section.has_public_children?).to be false
    end
  end

  describe '#ordered_children' do
    it 'returns items ordered by ordinal' do
      item1 = FactoryBot.create(:guide_item, section_id: section.id, ordinal: 2)
      item2 = FactoryBot.create(:guide_item, section_id: section.id, ordinal: 1)
      item3 = FactoryBot.create(:guide_item, section_id: section.id, ordinal: 3)

      expect(section.ordered_children).to eq([item2, item1, item3])
    end

    it 'returns empty array when section has no items' do
      expect(section.ordered_children).to be_empty
    end
  end

  describe '#parent' do
    it 'returns nil for sections' do
      expect(section.parent).to be_nil
    end
  end

  describe '.anchors_in_use' do
    it 'returns array of all unique anchors' do
      section_with_anchor = FactoryBot.create(:guide_section, anchor: 'section-1')
      item_with_anchor = FactoryBot.create(:guide_item, section_id: section_with_anchor.id, anchor: 'item-1')
      subitem_with_anchor = FactoryBot.create(:guide_subitem, item_id: item_with_anchor.id, anchor: 'subitem-1')

      anchors = Guide::Section.anchors_in_use
      expect(anchors).to include('section-1', 'item-1', 'subitem-1')
    end

    it 'returns empty array when no anchors are defined' do
      anchors = Guide::Section.anchors_in_use
      expect(anchors).to be_a Array
    end
  end

  describe '.transfer_path' do
    it 'returns the correct path' do
      expect(Guide::Section.transfer_path).to eq('/tmp/guide_transfer.txt')
    end
  end
end
