# frozen_string_literal: true

# This type of user comes from the shibboleth authentication strategy
class User::Shibboleth < User::User
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

  def update_with_omniauth(auth)
    update_attribute(:provider, auth["provider"])
    update_attribute(:uid, auth["uid"])
    update_attribute(:email, auth["info"]["email"])
    update_attribute(:username, email.split("@").first)
    update_attribute(:name, auth["info"]["name"])
    update_attribute(:role, User::Shibboleth.user_role(auth))
    self
  end

  def self.user_role(auth)
    admins = IDB_CONFIG[:admin][:netids].split(",").map {|x| x.strip || x }
    net_id = auth["info"]["email"].split("@").first
    return Databank::UserRole::ADMIN if admins.include?(net_id)

    user = User::Shibboleth.find_by(provider: auth["provider"], uid: auth["uid"])
    return Databank::UserRole::DEPOSITOR if user && user_can?("Dataset", nil, "create", user)

    if auth["extra"]["raw_info"]["iTrustAffiliation"].respond_to?(:split)
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
    else
      raise("missing iTrustAffiliation")
    end
  rescue StandardError => e
    Rails.logger.warn("error determining user role #{e.message} for #{auth.to_yaml}")
    notification = DatabankMailer.error("error determining user role #{e.message} for #{auth.to_yaml}")
    notification.deliver_now
    Databank::UserRole::NO_DEPOSIT
  end
end
