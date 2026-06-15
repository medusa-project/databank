require 'rails_helper'

RSpec.describe RestorationEvent, type: :model do
  let(:event) { FactoryBot.create(:restoration_event) }

  describe 'associations' do
    it 'has many restoration id maps' do
      expect(event).to have_many(:restoration_id_maps).dependent(:destroy)
    end
  end

  describe 'destruction' do
    it 'destroys associated restoration id maps' do
      map = FactoryBot.create(:restoration_id_map, restoration_event_id: event.id)
      expect { event.destroy }.to change(RestorationIdMap, :count).by(-1)
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:event_type) }
    it { is_expected.to validate_presence_of(:event_date) }
  end
end
