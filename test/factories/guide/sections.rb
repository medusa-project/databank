FactoryBot.define do
  factory :guide_section, class: 'Guide::Section' do
    anchor { "MyString" }
    label { "MyString" }
    ordinal { 1 }
  end
end
