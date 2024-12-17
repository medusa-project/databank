# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    provider { "developer" }
    uid { SecureRandom.uuid }
    email { Faker::Internet.email }
    username { email.split("@").first }
    name { Faker::Name.name }
    role { "depositor" }

    trait :admin do
      role { "admin" }
    end

    trait :reviewer do
      role { "reviewer" }
    end

    trait :guest do
      role { "guest" }
    end
  end
end