# spec/factories/user_abilities.rb
FactoryBot.define do
  factory :user_ability do
    user_provider { "developer" }
    user_uid { SecureRandom.uuid }
    resource_type { "Databank" }
    resource_id { nil }
    ability { "manage" }

    trait :curator do
      resource_type { "Databank" }
      resource_id { nil }
      ability { "manage" }
    end

    trait :deposit_exception do
      resource_type { "Dataset" }
      resource_id { nil }
      ability { "create" }
    end
  end
end
