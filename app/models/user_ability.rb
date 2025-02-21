# frozen_string_literal: true

# Represents a user's ability to perform a specific action on a specific resource.
# For example, a UserAbility record might represent a user's ability to read a specific dataset.
# Used by and coordinating with the ability class, but for more granular control than broad role-based authorizations
#
# # Attributes
# * +resource_type+ [String] The type of the resource that the user has permission to access.
# * +resource_id+ [Integer] The ID of the resource that the user has permission to access.
# * +user_provider+ [String] The provider of the user that has permission to access the resource.
# * +user_uid+ [String] The UID of the user that has permission to access the resource.
# * +ability+ [String] The ability that the user has to access the resource.

class UserAbility < ApplicationRecord

  before_save :trim_values

  def deposit_exception?
    return false unless resource_id.nil?
    return false unless resource_type == "Dataset"
    return false unless ability == "create"

    true
  end

  def curator?
    return false unless resource_id.nil?
    return false unless resource_type == "Databank"
    return false unless ability == "manage"

    true
  end

  def trim_values
    self.resource_type = resource_type.strip if resource_type
    self.user_provider = user_provider.strip if user_provider
    self.user_uid = user_uid.strip if user_uid
    self.ability = ability.strip if ability
  end

  class << self
    # @param [String] model The type of the resource that the user has permission to access.
    # @param [Integer] model_id The ID of the resource that the user has permission to access.
    # @param [String] ability The ability that the user has to access the resource.
    # @param [User] user The user that has permission to access the resource.
    # @return [Boolean] Whether the user has the specified ability to access the specified resource.
    def user_can?(model, model_id, ability, user)
      return false unless user

      UserAbility.where(resource_type: model,
                        resource_id:   model_id,
                        user_provider: user.provider,
                        user_uid:      user.uid,
                        ability:       ability).exists?
    end

    # used to add a user to the list of curators for a databank
    # @param [User] user The user to add to the list of curators
    def add_curator(user:)
      UserAbility.create(resource_type: "Databank",
                          user_provider: user.provider,
                          user_uid:      user.uid,
                          ability:       "manage")
      Application.admin_uids << user.uid
    end

    # used to remove a user from the list of curators for a databank
    # @param [User] user The user to remove from the list of curators
    def remove_curator(user:)
      UserAbility.where(resource_type: "Databank",
                        model_id:      nil,
                        user_provider: user.provider,
                        user_uid:      user.uid,
                        ability:       "manage").destroy_all
      Application.admin_uids.delete(user.uid)
    end

    def curators
      UserAbility.where(resource_type: "Databank", resource_id: nil, ability: "manage")
    end

    # used to grant the ability to deposit to a user who does not have it by default, graduates and ex-employees
    # @param [User] user The user to grant the ability to deposit, used when not granted by shib attributes.
    def grant_deposit_exception(user:)
      UserAbility.create(resource_type: "Dataset",
                         user_provider: user.provider,
                         user_uid:      user.uid,
                         ability:       "create")
    end

    # used to revoke the ability to deposit from a user who does not have it by default, graduates and ex-employees
    # @param [User] user The user to revoke the ability to deposit, used when not granted by shib attributes.
    def revoke_deposit_exception(user:)
      UserAbility.where(resource_type: "Dataset",
                        model_id:      nil,
                        user_provider: user.provider,
                        user_uid:      user.uid,
                        ability:       "create").destroy_all
    end

    # used to update the list of reviewers and editors for a dataset
    # @param [String] dataset_key The key of the dataset to update
    # @param [Array<String>] form_reviewers The list of reviewers to update to
    # @param [Array<String>] form_editors The list of editors to update to
    def update_permissions(dataset_key, form_reviewers=[], form_editors=[])
      dataset = Dataset.find_by(key: dataset_key)
      raise StandardError.new("dataset not found") unless dataset

      current_reviewers = dataset.reviewer_emails || []
      current_editors = dataset.editor_emails || []

      form_can_read = form_editors + form_reviewers
      current_can_read = current_reviewers + current_editors

      update_reviewers(dataset: dataset, form_can_read: form_can_read, current_can_read: current_can_read)
      update_editors(dataset: dataset, form_editors: form_editors, current_editors: current_editors)
    end

    # used to update the list of reviewers for a dataset
    # @param [Dataset] dataset The dataset to update
    # @param [Array<String>] form_can_read The list of identifiers for users to permit to read the dataset
    # @param [Array<String>] current_can_read The list of identifiers for users currently permitted to read the dataset
    # @return [Boolean] Whether the user was successfully added to the list of reviewers
    def update_reviewers(dataset:, form_can_read:, current_can_read:)
      remove_read = current_can_read - form_can_read
      remove_read.each do |email|
        revoke(dataset: dataset, email: email, ability: :read)
        revoke(dataset: dataset, email: email, ability: :view_files)
      end

      add_read = form_can_read - current_can_read
      add_read.each do |email|
        grant(dataset: dataset, email: email, ability: :read)
        grant(dataset: dataset, email: email, ability: :view_files)
      end
      true
    end

    # used to update the list of editors for a dataset
    # @param [Dataset] dataset The dataset to update
    # @param [Array<String>] form_editors The list of identifiers for users to permit to edit the dataset
    # @param [Array<String>] current_editors The list of identifiers for users currently permitted to edit the dataset
    # @return [Boolean] Whether the user was successfully added to the list of editors
    def update_editors(dataset:, current_editors:, form_editors:)
      remove_update = current_editors - form_editors
      remove_update.each do |email|
        revoke(dataset: dataset, email: email, ability: :update)
      end

      add_update = form_editors - current_editors
      add_update.each do |email|
        grant(dataset: dataset, email: email, ability: :update)
      end
      true
    end

    # used to add a user to the list of editors for a dataset
    # @param [Dataset] dataset The dataset to update
    # @param [String] email The email of the user to add to the list of editors
    # @return [Boolean] Whether the user was successfully added to the list of editors
    def add_to_editors(dataset:, email:)
      return true if dataset.editor_emails.include?(email)

      grant(dataset: dataset, email: email, ability: :read)
      grant(dataset: dataset, email: email, ability: :view_files)
      grant(dataset: dataset, email: email, ability: :update)
    end

    def remove_from_editors(dataset:, email:)
      return true unless dataset.editor_emails.include?(email)

      revoke(dataset: dataset, email: email, ability: :read)
      revoke(dataset: dataset, email: email, ability: :view_files)
      revoke(dataset: dataset, email: email, ability: :update)
    end

    # used to add an ability to a user for a dataset
    # @param [Dataset] dataset The dataset to update
    # @param [String] email The email of the user to grant the ability to
    # @param [String] ability The ability to grant the user
    # @return [Boolean] Whether the user was successfully granted the ability
    def grant(dataset:, email:, ability:)
      email = email.strip.downcase
      user = User.find_by(email: email)
      return grant_external(dataset: dataset, user: user, ability: ability) if user

      return false unless email[-12..] == "illinois.edu"

      existing_record = UserAbility.find_by(resource_type: "Dataset",
                                            resource_id:   dataset.id,
                                            user_provider: "shibboleth",
                                            user_uid:      email,
                                            ability:       ability)
      existing_record ||= UserAbility.create!(resource_type: "Dataset",
                                              resource_id:   dataset.id,
                                              user_provider: "shibboleth",
                                              user_uid:      email,
                                              ability:       ability)
      raise "#{ability} record not created for #{email}, #{dataset.key}" unless existing_record
    end

    # used to add an ability to a user for a dataset to an external user
    # @param [Dataset] dataset The dataset to update
    # @param [User] user The user to grant the ability to
    # @param [String] ability The ability to grant the user
    # @return [Boolean] Whether the user was successfully granted the ability
    def grant_external(dataset:, user:, ability:)
      existing_record = UserAbility.find_by(resource_type: "Dataset",
                                            resource_id:   dataset.id,
                                            user_provider: user.provider,
                                            user_uid:      user.email,
                                            ability:       ability)
      existing_record ||= UserAbility.create!(resource_type: "Dataset",
                                              resource_id:   dataset.id,
                                              user_provider: user.provider,
                                              user_uid:      user.email,
                                              ability:       ability)
      raise "#{ability} record not created for #{user.email}, #{dataset.key}" unless existing_record
    end

    # used to remove an ability from a user for a dataset
    # @param [Dataset] dataset The dataset to update
    # @param [String] email The email of the user to revoke the ability from
    # @param [String] ability The ability to revoke from the user
    # @return [Boolean] Whether the user was successfully revoked the ability
    def revoke(dataset:, email:, ability:)
      email = email.strip.downcase
      user = User.find_by(email: email)
      return revoke_external(dataset: dataset, user: user, ability: ability) if user

      return false unless email[-12..] == "illinois.edu"

      existing_record = UserAbility.find_by(resource_type: "Dataset",
                                            resource_id:   dataset.id,
                                            user_provider: "shibboleth",
                                            user_uid:      email,
                                            ability:       ability)
      existing_record&.destroy
      true
    end

    # used to remove an ability from a user for a dataset from an external user
    # @param [Dataset] dataset The dataset to update
    # @param [User] user The user to revoke the ability from
    # @param [String] ability The ability to revoke from the user
    # @return [Boolean] Whether the user was successfully revoked the ability
    def revoke_external(dataset:, user:, ability:)
      existing_record = UserAbility.find_by(resource_type: "Dataset",
                                            resource_id:   dataset.id,
                                            user_provider: user.provider,
                                            user_uid:      user.email,
                                            ability:       ability)
      existing_record&.destroy
      true
    end
  end
end
