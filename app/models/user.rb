# frozen_string_literal: true

require "open-uri"
require "json"

module User
  # This is an abstract class to represent a User
  # Class methods used because Shibboleth identities are not persistent in databank

  class User < ApplicationRecord
    include ActiveModel::Serialization

    validates :uid, uniqueness: {allow_blank: false}
    before_save :downcase_email
    validates :name,  presence: true
    validates :email, presence: true, length: {maximum: 255},
              format: {with: VALID_EMAIL_REGEX},
              uniqueness: {case_sensitive: false}

    class_attribute :system_user

    def is?(requested_role)
      role == requested_role.to_s
    end

    def self.system_user
      system_user = User.find_by(provider: "system", uid: IDB_CONFIG[:system_user_email])
      system_user ||= User.create_system_user
      system_user
    end

    # Converts email to all lower-case.
    def downcase_email
      self.email = email.downcase
    end

    def group
      if provider == "shibboleth"
        provider
      elsif provider == "identity"
        invitee = Invitee.find_by(email: email)
        if invitee
          invitee.group
        else
          raise StandardError.new("no invitation found for identity: #{email}")
        end
      end
    end

    def self.from_omniauth(_auth)
      raise "subclass responsibility"
    end

    def self.create_with_omniauth(_auth)
      raise "subclass responsibility"
    end

    def update_with_omniauth(_auth)
      raise "subclass responsibility"
    end

    def self.user_role(_email)
      raise "subclass responsibility"
    end

    def self.display_name(_email)
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
