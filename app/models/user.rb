# frozen_string_literal: true

require "open-uri"
require "json"

module User
  # This is an abstract class to represent a User. It is intended to be subclassed

  class User < ApplicationRecord
    include ActiveModel::Serialization

    validates :uid, uniqueness: {allow_blank: false}
    before_save :downcase_email
    validates :name,  presence: true
    validates :email, presence: true, length: {maximum: 255},
              format: {with: VALID_EMAIL_REGEX},
              uniqueness: {case_sensitive: false}
    # system user is a special user that is used to perform system tasks such as releasing embargoed datasets
    class_attribute :system_user

    # @return [Boolean] true if the user is an admin
    def admin?
      role == Databank::UserRole::ADMIN
    end

    # @return [Boolean] true if the user is a depositor
    def depositor?
      role == Databank::UserRole::DEPOSITOR
    end

    # @return [Boolean] true if the user is a guest
    def guest?
      role == Databank::UserRole::GUEST
    end

    # @return [Boolean] true if the user is a network reviewer
    def network_reviewer?
      role == Databank::UserRole::NETWORK_REVIEWER
    end

    # @param [User] user the user to check
    # @return [Array<Dataset>] the datasets the user can view
    def datasets_user_can_view(user:)
      forbidden_hold_states = [Databank::PublicationState::TempSuppress::VERSION,
                               Databank::PublicationState::PermSuppress::METADATA]
      case user.role
      when Databank::UserRole::ADMIN
        Dataset.all
      when Databank::UserRole::DEPOSITOR
        datasets = Dataset.select(&:metadata_public?)
        datasets += Dataset.where(depositor_email: user.email)
        ability_datasets = UserAbility.where(user_provider: user.provider,
                                             user_uid:      user.email,
                                             resource_type: "Dataset",
                                             ability:       :read).pluck(:resource_id)
        datasets += Dataset.where(id: ability_datasets)
        datasets -= Dataset.where(hold_state: forbidden_hold_states)
        datasets -= Dataset.where(publication_state: Databank::PublicationState::PermSuppress::METADATA)
        datasets.uniq
      when Databank::UserRole::NETWORK_REVIEWER
        datasets = Dataset.select(&:metadata_public?)
        datasets += Dataset.where(data_curation_network: true)
        datasets -= Dataset.where(hold_state: forbidden_hold_states)
        datasets -= Dataset.where(publication_state: Databank::PublicationState::PermSuppress::METADATA)
        datasets.uniq
      else
        Dataset.select(&:metadata_public?)
      end
    end

    # @param [User] user the user to check
    # @return [Array<Dataset>] the datasets the user can edit
    def datasets_user_can_edit(user:)
      forbidden_hold_states = [Databank::PublicationState::TempSuppress::VERSION,
                               Databank::PublicationState::PermSuppress::METADATA]
      case user.role
      when Databank::UserRole::ADMIN
        Dataset.all
      when Databank::UserRole::DEPOSITOR
        datasets = Dataset.where(depositor_email: user.email)
        ability_datasets = UserAbility.where(user_provider: user.provider,
                                             user_uid:      user.email,
                                             resource_type: "Dataset",
                                             ability:       :update).pluck(:resource_id)
        datasets += Dataset.where(id: ability_datasets)
        datasets -= Dataset.where(hold_state: forbidden_hold_states)
        datasets -= Dataset.where(publication_state: Databank::PublicationState::PermSuppress::METADATA)
        datasets.uniq
      else
        []
      end
    end

    # @param [String] requested_role the role to check if this user is
    def is?(requested_role)
      role == requested_role.to_s
    end

    # @return [User] the system user
    def self.system_user
      system_user = User.find_by(provider: "system", uid: IDB_CONFIG[:system_user_email])
      system_user ||= User.create_system_user
      system_user
    end

    # Converts email to all lower-case.
    def downcase_email
      self.email = email.downcase
    end

    # @return [String] the user's group, which is the provider for Shibboleth users and the group for Identity users
    def group
      case provider
      when "shibboleth"
        provider
      when "identity"
        invitee = Invitee.find_by(email: email)
        return invitee.group if invitee

        raise StandardError.new("no invitation found for identity: #{email}")
      else
        raise StandardError.new("unknown provider: #{provider}")
      end
    end

    # @param [Hash] auth the omniauth hash
    # @return [User] the user created from the omniauth hash
    def self.from_omniauth(_auth)
      raise "subclass responsibility"
    end

    # @param [Hash] auth the omniauth hash
    # @return [User] the user created from the omniauth hash
    def self.create_with_omniauth(_auth)
      raise "subclass responsibility"
    end

    # @param [Hash] auth the omniauth hash
    # @return [User] the user updated from the omniauth hash
    def update_with_omniauth(_auth)
      raise "subclass responsibility"
    end

    # @param [String] email the email to check
    # @return [String] the role of the user
    def self.user_role(_email)
      raise "subclass responsibility"
    end

    # @param [String] email the email to check
    # @return [String] the display name of the user
    def self.display_name(_email)
      raise "subclass responsibility"
    end

    class << self
      # creates the system user
      # @return [User] the system user
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
