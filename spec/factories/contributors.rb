FactoryBot.define do
  factory :contributor do
    dataset
    given_name { 'Alex' }
    family_name { 'Smith' }
    institution_name { nil }
    identifier { nil }
    type_of { Databank::CreatorType::PERSON }
    row_order { 1 }
    row_position { 1 }
    email { 'alex.smith@example.org' }
    identifier_scheme { 'ORCID' }

    trait :institution do
      given_name { nil }
      family_name { nil }
      institution_name { 'Campus Office' }
      type_of { Databank::CreatorType::INSTITUTION }
      email { 'office@example.org' }
    end
  end
end