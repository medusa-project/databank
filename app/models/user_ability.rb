# frozen_string_literal: true

class UserAbility < ApplicationRecord
  class << self
    def user_can?(model, model_id, ability, user)
      return false unless user

      UserAbility.where(resource_type: model,
                        resource_id:   model_id,
                        user_provider: user.provider,
                        user_uid:      user.uid,
                        ability:       ability).exists?
    end

    def grant_deposit_exception(user:)
      UserAbility.create(resource_type: "Dataset",
                         user_provider: user.provider,
                         user_uid:      user.uid,
                         ability:       "create")
    end

    def revoke_deposit_exception(user:)
      UserAbility.where(resource_type: "Dataset",
                        model_id:      nil,
                        user_provider: user.provider,
                        user_uid:      user.uid,
                        ability:       "create").destroy_all
    end

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
    end

    def update_editors(dataset:, current_editors:, form_editors:)
      remove_update = current_editors - form_editors
      remove_update.each do |email|
        revoke(dataset: dataset, email: email, ability: :update)
      end

      add_update = form_editors - current_editors
      add_update.each do |email|
        grant(dataset: dataset, email: email, ability: :update)
      end
    end

    def add_to_editors(dataset:, email:)
      return true if dataset.editor_emails.include?(email)

      return false if email[-12..] != "illinois.edu" && !User::Identity.find_by(email: email)

      grant(dataset: dataset, email: email, ability: :read)
      grant(dataset: dataset, email: email, ability: :view_files)
      grant(dataset: dataset, email: email, ability: :update)
    end

    def remove_from_editors(dataset:, email:)
      return true unless dataset.editor_emails.include?(email)

      return false if email[-12..] != "illinois.edu" && !User::Identity.find_by(email: email)

      revoke(dataset: dataset, email: email, ability: :read)
      revoke(dataset: dataset, email: email, ability: :view_files)
      revoke(dataset: dataset, email: email, ability: :update)
    end

    def grant(dataset:, email:, ability:)
      email = email.strip.downcase
      user = User::Identity.find_by(email: email)
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

    def revoke(dataset:, email:, ability:)
      email = email.strip.downcase
      user = User::Identity.find_by(email: email)
      return revoke_external(dataset: dataset, user: user, ability: ability) if user

      return false unless email[-12..] == "illinois.edu"

      existing_record = UserAbility.find_by(resource_type: "Dataset",
                                            resource_id:   dataset.id,
                                            user_provider: "Shibboleth",
                                            user_uid:      email,
                                            ability:       ability)
      existing_record&.destroy
    end

    def revoke_external(dataset:, user:, ability:)
      existing_record = UserAbility.find_by(resource_type: "Dataset",
                                            resource_id:   dataset.id,
                                            user_provider: user.provider,
                                            user_uid:      user.email,
                                            ability:       ability)
      existing_record&.destroy
    end
  end
end
