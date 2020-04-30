# frozen_string_literal: true

# This type of user comes from the identity authentication strategy

class User::Identity < User::User
  def self.from_omniauth(auth)
    raise("missing or invalid auth") unless auth && auth[:uid] && auth["info"]["email"]

    if auth && auth[:uid] && auth["info"]["email"]
      email = auth["info"]["email"].strip
      identity = Identity.find_by(email: email)
      if identity&.activated
        user = User::Identity.find_by(provider: auth["provider"], uid: auth["uid"])
        if user
          user.update_with_omniauth(auth)
        else
          user = User::Identity.create_with_omniauth(auth)
        end
        user
      end
    end
  end

  def self.create_with_omniauth(auth)
    invitee = Invitee.find_by(email: auth["info"]["email"])
    if invitee&.expires_at >= Time.current
      create! do |user|
        user.provider = auth["provider"]
        user.uid = auth["uid"]
        user.email = auth["info"]["email"]
        user.name = auth["info"]["name"]
        user.username = user.email
        user.role = user_role(user.email)
      end
    end
  end

  def update_with_omniauth(auth)
    update_attribute(:provider, auth["provider"])
    update_attribute(:uid, auth["uid"])
    update_attribute(:email, auth["info"]["email"])
    update_attribute(:username, email.split("@").first)
    update_attribute(:name, auth["info"]["name"])
    update_attribute(:role, User::Identity.user_role(email))
    self
  end

  def self.user_role(email)
    invitee = Invitee.find_by(email: email)
    if invitee
      invitee.role
    else
      Databank::UserRole::GUEST
    end
  end

  def self.display_name(email)
    identity = find_by(email: email)
    return email unless identity

    identity.name || email
  end
end
