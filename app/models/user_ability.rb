# frozen_string_literal: true

class UserAbility < ApplicationRecord
  class << self
    def user_can?(model, model_id, ability, user)
      user ||= User::Shibboleth.new # guest user (not logged in)
      UserAbility.where(resource_type: model,
                        resource_id:   model_id,
                        user_provider: user.provider,
                        user_uid:      user.uid,
                        ability:       ability).exists?
    end

    def update_internal_permissions(dataset_key, form_reviewers=[], form_editors=[])
      dataset = Dataset.find_by(key: dataset_key)
      raise("dataset not found") unless dataset

      current_reviewers = dataset.internal_reviewer_netids || []
      current_editors = dataset.internal_editor_netids || []

      form_can_read = form_editors + form_reviewers
      current_can_read = current_reviewers + current_editors

      remove_read = current_can_read - form_can_read
      remove_read.each do |netid|
        revoke_internal(dataset, netid, :read)
        revoke_internal(dataset, netid, :view_files)
      end

      add_read = form_can_read - current_can_read
      add_read.each do |netid|
        grant_internal(dataset, netid, :read)
        grant_internal(dataset, netid, :view_files)
      end

      remove_update = current_editors - form_editors
      remove_update.each do |netid|
        revoke_internal(dataset, netid, :update)
      end

      add_update = form_editors - current_editors
      add_update.each do |netid|
        grant_internal(dataset, netid, :update)
      end
    end

    def grant_internal(dataset, netid, ability)
      existing_record = UserAbility.find_by(resource_type: "Dataset",
                                            resource_id:   dataset.id,
                                            user_provider: "shibboleth",
                                            user_uid:      "#{netid}@illinois.edu",
                                            ability:       ability)
      existing_record ||= UserAbility.create!(resource_type: "Dataset",
                                              resource_id:   dataset.id,
                                              user_provider: "shibboleth",
                                              user_uid:      "#{netid}@illinois.edu",
                                              ability:       ability)
      raise "#{ability} record not created for #{netid}, #{dataset.key}" unless existing_record
    end

    def revoke_internal(dataset, netid, ability)
      existing_record = UserAbility.find_by(resource_type: "Dataset",
                                            resource_id:   dataset.id,
                                            user_provider: "shibboleth",
                                            user_uid:      "#{netid}@illinois.edu",
                                            ability:       ability)
      existing_record&.destroy
    end
  end
end
