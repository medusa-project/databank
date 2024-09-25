# frozen_string_literal: true

# This type of user comes from the shibboleth authentication strategy
class User::Shibboleth < User::User

  validates :email, presence: true, uniqueness: true
  validates :role, presence: true

  # This method is called by the omniauth callback controller
  # to create or update a user based on the omniauth response
  # It will return the user if it exists or create a new one if it does not
  # @return [User::Shibboleth] the user
  def self.from_omniauth(auth)
    if auth && auth[:uid]
      user = User::Shibboleth.find_by(provider: auth["provider"], uid: auth["uid"])

      if user
        user.update_with_omniauth(auth)
      else
        user = User::Shibboleth.create_with_omniauth(auth)
      end
      user

    end
  end

  # This method is called by the omniauth callback controller's from_omniauth method
  # to create a new user based on the omniauth response
  # @param auth [Hash] the omniauth response
  # @return [User::Shibboleth] the user
  def self.create_with_omniauth(auth)
    create! do |user|
      user.provider = auth["provider"]
      user.uid = auth["uid"]
      user.email = auth["info"]["email"]
      user.username = (auth["info"]["email"]).split("@").first
      user.name = auth["info"]["name"]
      user.role = user_role(auth)
    end
  end

  # This method is called by the omniauth callback controller's from_omniauth method
  # to update an existing user based on the omniauth response
  # @param auth [Hash] the omniauth response
  # @return [User::Shibboleth] the user
  def update_with_omniauth(auth)
    update_attribute(:provider, auth["provider"])
    update_attribute(:uid, auth["uid"])
    update_attribute(:email, auth["info"]["email"])
    update_attribute(:username, email.split("@").first)
    update_attribute(:name, auth["info"]["name"])
    update_attribute(:role, User::Shibboleth.user_role(auth))
    self
  end

  # @return [String] the netid of the user
  def netid
    email.split("@")[0]
  end

  # @return [String] the email of the user
  # @param auth [Hash] the omniauth response
  # @return [String] the email of the user
  def self.user_role(auth)
    admins = IDB_CONFIG[:admin][:netids].split(",").map {|x| x.strip || x }
    net_id = auth["info"]["email"].split("@").first
    return Databank::UserRole::ADMIN if admins.include?(net_id)

    user = User::Shibboleth.find_by(provider: auth["provider"], uid: auth["uid"])
    return Databank::UserRole::DEPOSITOR if user && UserAbility.user_can?("Dataset", nil, "create", user)

    unless auth["extra"]["raw_info"]["iTrustAffiliation"].respond_to?(:split)
      raise StandardError.new("missing iTrustAffiliation")
    end

    affiliations = auth["extra"]["raw_info"]["iTrustAffiliation"].split(";")
    if affiliations.respond_to?(:length) && !affiliations.empty?
      return Databank::UserRole::DEPOSITOR if affiliations.include?("staff")

      if affiliations.include?("student")
        if auth["extra"]["raw_info"]["uiucEduStudentLevelCode"] == "1U"
          Databank::UserRole::NO_DEPOSIT
        else
          Databank::UserRole::DEPOSITOR
        end
      end
    else
      Rails.logger.warn("unexpected auth: #{auth.to_yaml}")
      notification = DatabankMailer.error("Unexpected auth response: #{auth.to_yaml}")
      notification.deliver_now
      Databank::UserRole::NO_DEPOSIT
    end
  rescue StandardError => e
    Rails.logger.warn("error determining user role #{e.message} for #{auth.to_yaml}")
    notification = DatabankMailer.error("error determining user role #{e.message} for #{auth.to_yaml}")
    notification.deliver_now
    Databank::UserRole::NO_DEPOSIT
  end
end
