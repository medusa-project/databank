require 'rails_helper'

RSpec.describe Guide::Subitem, type: :model do
  let(:item) { FactoryBot.create(:guide_item) }
  let(:subitem) { FactoryBot.create(:guide_subitem, item_id: item.id) }

  describe 'associations' do
    it 'belongs to a guide item' do
      expect(subitem).to belong_to(:guide_item).optional
    end
  end

  describe '#parent' do
    it 'returns the parent item' do
      expect(subitem.parent).to eq(item)
    end

    it 'returns nil when no item_id is set' do
      orphan_subitem = FactoryBot.create(:guide_subitem, item_id: nil)
      expect(orphan_subitem.parent).to be_nil
    end

    it 'returns nil when item does not exist' do
      subitem_with_missing_item = FactoryBot.create(:guide_subitem, item_id: 99999)
      expect(subitem_with_missing_item.parent).to be_nil
    end
  end
end
