FactoryBot.define do
  factory :guide_item, class: 'Guide::Item' do
    section_id { create(:guide_section).id }
    sequence(:anchor) { |n| "item-anchor-#{n}" }
    sequence(:label) { |n| "Item #{n}" }
    sequence(:ordinal) { |n| n }
    heading { 'Item heading' }
    body { 'Item body' }
    public { true }
  end
end
