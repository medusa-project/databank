require 'rails_helper'

RSpec.describe Guide, type: :model do
  describe '.table_name_prefix' do
    it 'returns the correct table prefix' do
      expect(described_class.table_name_prefix).to eq('guide_')
    end
  end
end
