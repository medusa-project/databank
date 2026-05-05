FactoryBot.define do
  factory :creator do
    dataset
    given_name { 'Jane' }
    family_name { 'Doe' }
    institution_name { nil }
    identifier { nil }
    type_of { Databank::CreatorType::PERSON }
    row_order { 1 }
    row_position { 1 }
    email { 'jane.doe@example.org' }
    is_contact { false }
    identifier_scheme { 'ORCID' }

    trait :contact do
      is_contact { true }
    end

    trait :institution do
      given_name { nil }
      family_name { nil }
      institution_name { 'University Library' }
      type_of { Databank::CreatorType::INSTITUTION }
      email { 'library@example.org' }
    end
  end
end
