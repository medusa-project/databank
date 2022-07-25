# frozen_string_literal: true

# defines which users have permission to perform which actions
class Ability
  include CanCan::Ability

  def initialize(user)
    # cancancan automatically adds read, create, update
    # alias_action :index, :show, :to => :read
    # alias_action :new, :to => :create
    # alias_action :edit, :to => :update

    user ||= User::Shibboleth.new # guest user (not logged in)

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

    can :read, Dataset do |dataset|
      dataset.metadata_public? ||
          dataset.depositor_email == user.email ||
          UserAbility.user_can?("Dataset", dataset.id, :update, user) ||
          UserAbility.user_can?("Dataset", dataset.id, :read, user) ||
          dataset.data_curation_network && user.is?(Databank::UserRole::NETWORK_REVIEWER)
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

    can [:read, :update], Identity do |identity|
      identity.email == user.email
    end

    can :read, [Guide::Section, Guide::Item, Guide::Subitem], &:public?

  end
end
