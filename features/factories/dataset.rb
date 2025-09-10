FactoryBot.define do
  factory :dataset do
    sequence(:title) {|n| "Title#{n}" }
    sequence(:key) {|n| "key#{n}" }
    license {"CC01"}
  end
end