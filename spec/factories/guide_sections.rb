FactoryBot.define do
  factory :guide_section, class: 'Guide::Section' do
    sequence(:anchor) { |n| "section-anchor-#{n}" }
    sequence(:label) { |n| "Section #{n}" }
    sequence(:ordinal) { |n| n }
    heading { 'Section heading' }
    body { 'Section body' }
    public { true }
  end
end
