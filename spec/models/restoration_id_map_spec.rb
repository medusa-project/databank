require 'rails_helper'

RSpec.describe RestorationIdMap, type: :model do
  let(:event) { FactoryBot.create(:restoration_event) }
  let(:id_map) { FactoryBot.create(:restoration_id_map, restoration_event_id: event.id) }

  describe 'associations' do
    it 'belongs to a restoration event' do
      expect(id_map).to belong_to(:restoration_event)
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:medusa_id) }
    it { is_expected.to validate_presence_of(:local_id) }
  end

  describe 'attributes' do
    it 'stores medusa_id and local_id' do
      id_map.medusa_id = 12345
      id_map.local_id = 67890
      id_map.save
      
      reloaded = RestorationIdMap.find(id_map.id)
      expect(reloaded.medusa_id).to eq(12345)
      expect(reloaded.local_id).to eq(67890)
    end
  end
end
