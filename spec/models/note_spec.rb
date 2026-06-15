require 'rails_helper'

RSpec.describe Note, type: :model do
  let(:dataset) { FactoryBot.create(:dataset) }
  let(:note) { FactoryBot.create(:note, dataset_id: dataset.id) }

  describe 'associations' do
    it 'belongs to a dataset' do
      expect(note).to belong_to(:dataset)
    end
  end

  describe 'attributes' do
    it 'stores body and author' do
      note.body = 'This is a curator note'
      note.author = 'curator@example.com'
      note.save

      reloaded = Note.find(note.id)
      expect(reloaded.body).to eq('This is a curator note')
      expect(reloaded.author).to eq('curator@example.com')
    end
  end
end
