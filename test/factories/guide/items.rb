FactoryBot.define do
  factory :guide_item, class: 'Guide::Item' do
    section_id { 1 }
    anchor { "MyString" }
    label { "MyString" }
    ordinal { 1 }
    heading { "MyString" }
    body { "MyString" }
  end
end
