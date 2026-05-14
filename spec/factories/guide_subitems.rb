FactoryBot.define do
  factory :guide_subitem, class: 'Guide::Subitem' do
    item_id { create(:guide_item).id }
    sequence(:anchor) { |n| "subitem-anchor-#{n}" }
    sequence(:label) { |n| "Subitem #{n}" }
    sequence(:ordinal) { |n| n }
    heading { 'Subitem heading' }
    body { 'Subitem body' }
    public { true }
  end
end
