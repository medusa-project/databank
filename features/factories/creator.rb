FactoryBot.define do
  factory :creator do
    sequence(:email) {|n| "user#{n}@example.com" }
    sequence(:family_name) {|n| "user#{n}@example.com" }
    sequence(:given_name) {|n| "user#{n}@example.com" }
    type_of { Databank::CreatorType::PERSON }
    row_order { 1 }
    row_position { 1 }
    is_contact { true }
  end
end