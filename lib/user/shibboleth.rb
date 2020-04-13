# This type of user comes from the shibboleth authentication strategy

require_relative '../user'

class User::Shibboleth < User::User

  def self.from_omniauth(auth)
    if auth && auth[:uid]
      user = User::Shibboleth.find_by_provider_and_uid(auth["provider"], auth["uid"])

      if user
        user.update_with_omniauth(auth)
      else
        user = User::Shibboleth.create_with_omniauth(auth)
      end
      return user

    else
      return nil
    end
  end

  def self.create_with_omniauth(auth)
    create! do |user|
      user.provider = auth["provider"]
      user.uid = auth["uid"]
      user.email = auth["info"]["email"]
      user.username = (auth["info"]["email"]).split('@').first
      user.name = auth["info"]["name"]
      user.role = user_role(auth["uid"])
    end
  end

  def update_with_omniauth(auth)
    update_attribute(:provider, auth["provider"])
    update_attribute(:uid, auth["uid"])
    update_attribute(:email, auth["info"]["email"])
    update_attribute(:username, self.email.split('@').first)
    update_attribute(:name, auth["info"]["name"])
    update_attribute(:role, User::Shibboleth.user_role(auth))
    self
  end

  def self.user_role(auth)
    admins = IDB_CONFIG[:admin][:netids].split(",").collect{|x| x.strip || x }
    net_id = auth["info"]["email"].split('@').first
    return Databank::UserRole::ADMIN if admins.include?(net_id)

    if auth["extra"]["raw_info"]["iTrustAffiliation"].respond_to?(:split)
      affiliations = auth["extra"]["raw_info"]["iTrustAffiliation"].split(";")

      if affiliations.respond_to?(:length) && affiliations.length > 0
        return Databank::UserRole::DEPOSITOR if affiliations.include("staff")

        if affiliations.include("student") &&
            auth["extra"]["raw_info"]["iTrustAffiliation"]["uiucEduStudentLevelCode"] == "1U"
          return Databank::UserRole::NO_DEPOSIT

        end
      end
    end
    return Databank::UserRole::GUEST
  end

end

