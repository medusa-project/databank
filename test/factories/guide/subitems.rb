FactoryBot.define do
  factory :guide_subitem, class: 'Guide::Subitem' do
    item_id { 1 }
    anchor { "MyString" }
    label { "MyString" }
    ordinal { 1 }
    heading { "MyString" }
    body { "MyString" }
  end
end
