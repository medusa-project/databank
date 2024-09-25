# frozen_string_literal: true

# This type of user comes from the identity authentication strategy

class User::Identity < User::User

  validates :email, presence: true, uniqueness: true
  validates :role, presence: true

  # This method is called by the omniauth callback controller
  # to create or update a user based on the omniauth response

  # Return the user if it exists or create a new one if it does not
  # @param auth [Hash] the omniauth response
  # @return [User::Identity] the user
  def self.from_omniauth(auth)
    raise StandardError.new("missing or invalid auth") unless auth && auth[:uid] && auth["info"]["email"]

    email = auth["info"]["email"].strip
    identity = Identity.find_by(email: email)
    raise StandardError.new("identity does not exist or is not activated for #{auth}") unless identity&.activated

    user = User::Identity.find_by(provider: auth["provider"], email: email)
    if user
      user.update_with_omniauth(auth)
    else
      user = User::Identity.create_with_omniauth(auth)
    end
    user
  end

  # This method is called by the omniauth callback controller's from_omniauth method
  # to create a new user based on the omniauth response
  # @param auth [Hash] the omniauth response
  # @return [User::Identity] the user
  def self.create_with_omniauth(auth)
    invitee = Invitee.find_by(email: auth["info"]["email"])
    if invitee&.expires_at >= Time.current
      create! do |user|
        user.provider = auth["provider"]
        user.uid = auth["info"]["email"]
        user.email = auth["info"]["email"]
        user.name = auth["info"]["name"]
        user.username = user.email
        user.role = user_role(user.email)
      end
    end
  end

  # This method is called by the omniauth callback controller's from_omniauth method
  # to update an existing user based on the omniauth response
  # @param auth [Hash] the omniauth response
  # @return [User::Identity] the user
  def update_with_omniauth(auth)
    update_attribute(:provider, auth["provider"])
    update_attribute(:uid, auth["info"]["email"])
    update_attribute(:email, auth["info"]["email"])
    update_attribute(:username, email.split("@").first)
    update_attribute(:name, auth["info"]["name"])
    update_attribute(:role, User::Identity.user_role(email))
    self
  end

  # This method is called by the user model to determine the role of a user
  # based on the email address
  # @param email [String] the email address
  # @return [String] the role
  def self.user_role(email)
    invitee = Invitee.find_by(email: email)
    if invitee
      invitee.role
    else
      Databank::UserRole::GUEST
    end
  end

  # This method is called by the user model to determine the display name of a user
  # based on the email address
  # @param email [String] the email address
  # @return [String] the display name
  def self.display_name(email)
    identity = find_by(email: email)
    return email unless identity

    identity.name || email
  end

  # This method is called by the user model to determine the netid of a user
  # based on the email address
  # @return [String] the netid if the environment is test or development, nil otherwise
  # netid has no meaning for the identity provider in production, but is mocked for development and testing
  def netid
    return username if Rails.env.test? || Rails.env.development?

    nil
  end
end
