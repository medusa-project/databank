# frozen_string_literal: true

FactoryBot.define do
  factory :invitee do
    sequence(:email) {|n| "user#{n}@example.com" }
    role { "admin" }
    expires_at { Date.current + 1.month }
  end
  factory :identity do
    localpass = IDB_CONFIG[:admin][:localpass]
    sequence(:name) {|n| "User #{n}" }
    sequence(:email) {|n| "user#{n}@example.com" }
    password { localpass }
    password_confirmation { localpass }
    salt = BCrypt::Engine.generate_salt
    encrypted_password = BCrypt::Engine.hash_secret(localpass, salt)
    password_digest { encrypted_password }
    activated { true }
    activated_at { Time.current - 1.month }
  end
end
