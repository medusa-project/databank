# frozen_string_literal: true

require "open-uri"
require "json"

class User < ApplicationRecord
  include ActiveModel::Serialization

  validates :uid, uniqueness: {allow_blank: false}
  before_save :downcase_email
  validates :name,  presence: true
  validates :email, presence: true, length: {maximum: 255},
            format: {with: VALID_EMAIL_REGEX},
            uniqueness: {case_sensitive: false}

  def system_admin?
    admin_netids = IDB_CONFIG[:admin][:netids].split(",").map {|x| x.strip || x }
    admin_uids = admin_netids.map {|x| x + "@illinois.edu" }
    return true if admin_uids.include?(uid)

    # Optional, non-production-only shortcut: allow users with the admin role
    # to be treated as system admins.
    allow_role_based_admin = (Rails.env.development? || Rails.env.test?)
    admin? && allow_role_based_admin
  end

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

  def self.curators
    curator_abilities = UserAbility.where(resource_type: 'Databank', ability: 'manage', resource_id: nil)
    curator_uids = curator_abilities.map {|x| x.user_uid }
    curators = User.where(uid: curator_uids)
  end

  def associated_curator_ability
    UserAbility.where(user_provider: provider, user_uid: uid, resource_type: 'Databank', ability: 'manage', resource_id: nil).first
  end

  # @param [String] resource_type the type of resource
  # @param [String] resource_id the id of the resource
  # @param [String] ability the ability to check
  # @param [User] user the user to check
  # @return [Boolean] true if the user has the ability
  def self.user_can?(resource_type, resource_id, ability, user)
    return false unless user
    return true if user.admin?
    return true if user.depositor? && ability == "create" && resource_type == "Dataset"
    return true if user.depositor? && ability == "read" && resource_type == "Dataset" && resource_id.nil?
    return true if user.depositor? && ability == "update" && resource_type == "Dataset" && resource_id.nil?
    return true if user.depositor? && ability == "destroy" && resource_type == "Dataset" && resource_id.nil?
    return true if user.depositor? && ability == "read" && resource_type == "Dataset" && resource_id && Dataset.find(resource_id).depositor_email == user.email
    return true if user.depositor? && ability == "update" && resource_type == "Dataset" && resource_id && Dataset.find(resource_id).depositor_email == user.email
    return true if user.depositor? && ability == "destroy" && resource_type == "Dataset" && resource_id && Dataset.find(resource_id).depositor_email == user.email
    return true if user.network_reviewer? && ability == "read" && resource_type == "Dataset" && resource_id.nil?
    return true if user.network_reviewer? && ability == "read" && resource_type == "Dataset" && resource_id && Dataset.find(resource_id).data_curation_network
    UserAbility.where(user_provider: user.provider, user_uid: user.uid, resource_type: resource_type, resource_id: resource_id, ability: ability).any?
  end

  # @param [String] resource_type the type of resource
  # @param [String] resource_id the id of the resource
  # @param [String] ability the ability to check
  # @param [User] user the user to check
  # @return [Boolean] true if the

  # @return [User] the system user
  def self.system_user
    system_user = User.find_by(provider: "system", uid: IDB_CONFIG[:system_user_email])
    system_user ||= User.create_system_user
    system_user
  end

  # @return [Array<String>] the uids of the admins
  def self.admin_uids
    # curator is an alias for admin
    config_admins = IDB_CONFIG[:admin][:netids].split(",").map {|x| x.strip || x }
    config_admin_uids = config_admins.map {|x| x + "@illinois.edu" }
    admin_user_abilities = UserAbility.where(resource_type: 'Databank', ability: 'manage', resource_id: nil)
    user_ability_admin_uids = admin_user_abilities.map {|x| x.user_uid }
    admin_uids = config_admin_uids + user_ability_admin_uids
    admin_uids
  end

  # Converts email to all lower-case.
  def downcase_email
    self.email = email.downcase
  end

# This method is called by the omniauth callback controller
  # to create or update a user based on the omniauth response
  # It will return the user if it exists or create a new one if it does not
  # @return [User] the user
  def self.from_omniauth(auth)
    if auth && auth[:uid]
      user = User.find_by(provider: auth["provider"], uid: auth["uid"])
      if user
        user.update_with_omniauth(auth)
      else
        user = User.create_with_omniauth(auth)
      end
      user

    end
  end

  # This method is called by the omniauth callback controller's from_omniauth method
  # to create a new user based on the omniauth response
  # @param auth [Hash] the omniauth response
  # @return [User] the user
  def self.create_with_omniauth(auth)
    if auth["provider"] == "shibboleth"
      auth["info"]["role"] = User.user_role(auth)
    end
    create! do |user|
      user.provider = auth["provider"]
      user.uid = auth["uid"]
      user.email = auth["info"]["email"]
      user.username = (auth["info"]["email"]).split("@").first
      user.name = auth["info"]["name"]
      user.role = auth["info"]["role"]
    end
  end

  # This method is called by the omniauth callback controller's from_omniauth method
  # to update an existing user based on the omniauth response
  # @param auth [Hash] the omniauth response
  # @return [User] the user
  def update_with_omniauth(auth)
    if auth["provider"] == "shibboleth"
      auth["info"]["role"] = User.user_role(auth)
    end
    update_attribute(:provider, auth["provider"])
    update_attribute(:uid, auth["uid"])
    update_attribute(:email, auth["info"]["email"])
    update_attribute(:username, email.split("@").first)
    update_attribute(:name, auth["info"]["name"])
    update_attribute(:role, auth["info"]["role"])
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

    return Databank::UserRole::ADMIN if User.admin_uids.include?(auth["uid"])

    # if the user is already in the database with explicit permission to create datasets, return depositor role
    user = User.find_by(provider: auth["provider"], uid: auth["uid"])
    return Databank::UserRole::DEPOSITOR if user && UserAbility.user_can?("Dataset", nil, "create", user)

    # new users require iTrustAffiliation to determine role
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

