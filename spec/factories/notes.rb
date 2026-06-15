FactoryBot.define do
  factory :note do
    association :dataset
    body { "Curator note" }
    author { "curator@example.com" }
  end
end
