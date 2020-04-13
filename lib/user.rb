require 'open-uri'
require 'json'

module User

  # This is an abstract class to represent a User
  # Class methods used because Shibboleth identities are not persistent in databank

  class User < ActiveRecord::Base
    include ActiveModel::Serialization

    validates_uniqueness_of :uid, allow_blank: false
    before_save :downcase_email
    validates :name,  presence: true
    validates :email, presence: true, length: { maximum: 255 },
              format: { with: VALID_EMAIL_REGEX },
              uniqueness: { case_sensitive: false }

    class_attribute :system_user

    def is? (requested_role)
      self.role == requested_role.to_s
    end

    def self.system_user
      system_user = User.find_by_provider_and_uid("system", IDB_CONFIG[:system_user_email])
      system_user = User.create_system_user unless system_user
      return system_user
    end

    # Converts email to all lower-case.
    def downcase_email
      self.email = email.downcase
    end

    def group
      if self.provider == 'shibboleth'
        self.provider
      elsif self.provider == 'identity'
        invitee = Invitee.find_by_email(self.email)
        if invitee
          invitee.group
        else
          raise("no invitation found for identity: #{self.email}")
        end
      end
    end

    def self.from_omniauth(auth)
      raise "subclass responsibility"
    end

    def self.create_with_omniauth(auth)
      raise "subclass responsibility"
    end

    def update_with_omniauth(auth)
      raise "subclass responsibility"
    end

    def self.user_role(email)
      raise "subclass responsibility"
    end

    def self.display_name(email)
      raise "subclass responsibility"
    end

    class << self
      def create_system_user
        create! do |user|
          user.provider = "system"
          user.uid = IDB_CONFIG[:system_user_email]
          user.name = IDB_CONFIG[:system_user_name]
          user.email = IDB_CONFIG[:system_user_email]
          user.username = IDB_CONFIG[:system_user_name]
          user.role = "admin"
        end
      end
    end

  end

end