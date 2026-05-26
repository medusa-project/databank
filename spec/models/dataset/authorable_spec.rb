require 'rails_helper'

RSpec.describe Dataset::Authorable, type: :model do
  describe '#ind_creators_to_contributors!' do
    it 'moves individual creators to contributors' do
      dataset = create(:dataset)
      create(:creator, dataset: dataset, given_name: 'Jane', family_name: 'Doe', email: 'jane.doe@example.org')

      expect {
        dataset.ind_creators_to_contributors!
      }.to change { dataset.reload.creators.count }.from(1).to(0)
        .and change { dataset.reload.contributors.count }.from(0).to(1)
    end
  end

  describe '#contributors_to_ind_creators!' do
    it 'raises and rolls back when any contributor cannot become a valid creator' do
      dataset = create(:dataset)
      create(:contributor, dataset: dataset, given_name: 'Valid', family_name: 'Person')
      create(:contributor, dataset: dataset, given_name: 'OnlyGiven', family_name: nil)

      expect {
        dataset.contributors_to_ind_creators!
      }.to raise_error(ActiveRecord::RecordInvalid)

      dataset.reload
      expect(dataset.contributors.count).to eq(2)
      expect(dataset.creators.count).to eq(0)
    end
  end
end
