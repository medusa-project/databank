# frozen_string_literal: true

##
# Defines user permissions for the application.
#
# The Ability class is a CanCanCan class that defines the permissions for the application.
#
# The class is initialized with a user object and defines the permissions for the user based on the user's role.

class Ability
  include CanCan::Ability
  ##
  # Initializes the Ability class with the user object.
  # @param [User] user the user object
  # @return [Ability] the initialized Ability object
  def initialize(user)
    # cancancan automatically adds read, create, update
    # alias_action :index, :show, :to => :read
    # alias_action :new, :to => :create
    # alias_action :edit, :to => :update

    user ||= User.new # guest user (not logged in)

    can :manage, :all if user.is?(Databank::UserRole::ADMIN)

    can :create, [Dataset, Datafile] if user.is?(Databank::UserRole::DEPOSITOR)

    can :manage, Datafile do |datafile|
      datafile.dataset.publication_state == Databank::PublicationState::DRAFT &&
        user.can?(:update, datafile.dataset)
    end

    can :view, Guide::Section do |section|
      section.public || section.has_public_children?
    end

    can :view, Guide::Item do |item|
      item.public || item.has_public_children?
    end

    can :view, Guide::Subitem, &:public

    can :view_version_acknowledgement, Dataset do |dataset|
      dataset.hold_state == Databank::PublicationState::TempSuppress::VERSION &&
        (dataset.depositor_email == user.email ||
        UserAbility.user_can?("Dataset", dataset.id, :update, user) ||
        UserAbility.user_can?("Dataset", dataset.id, :read, user))
    end

    can [:view, :read], Dataset do |dataset|
      dataset.hold_state != Databank::PublicationState::TempSuppress::VERSION && (dataset.metadata_public? ||
        dataset.depositor_email == user.email ||
        UserAbility.user_can?("Dataset", dataset.id, :update, user) ||
        UserAbility.user_can?("Dataset", dataset.id, :read, user) ||
        dataset.data_curation_network && user.is?(Databank::UserRole::NETWORK_REVIEWER))
    end

    can :update, Dataset do |dataset|
      dataset.depositor_email == user.email ||
        UserAbility.user_can?("Dataset", dataset.id, :update, user)
    end

    can :destroy, Dataset do |dataset|
      dataset.publication_state == Databank::PublicationState::DRAFT &&
        (dataset.depositor_email == user.email || UserAbility.user_can?("Dataset", dataset.id, :update, user))
    end

    can :view_files, Dataset do |dataset|
      dataset.files_public? ||
        dataset.depositor_email == user.email ||
        UserAbility.user_can?("Dataset", dataset.id, :update, user) ||
        UserAbility.user_can?("Dataset", dataset.id, :read, user) ||
        dataset.data_curation_network && user.is?(Databank::UserRole::NETWORK_REVIEWER)
    end

    can :read, [Guide::Section, Guide::Item, Guide::Subitem], &:public?
    can :search_orcid, Creator, &:public?
  end
end
