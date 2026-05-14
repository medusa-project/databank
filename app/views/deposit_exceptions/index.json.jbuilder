json.array! @user_abilities do |user_ability|
  json.extract! user_ability, :id, :user_provider, :user_uid, :resource_type, :resource_id, :ability, :created_at, :updated_at
  json.url deposit_exception_url(user_ability, format: :json)
end
