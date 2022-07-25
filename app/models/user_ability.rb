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

    def update_internal_permissions(dataset_key, form_reviewers=[], form_editors=[])

      form_reviewers = scrubbed_netids(input_array = form_reviewers)
      form_editors = scrubbed_netids(input_array = form_editors)
      dataset = Dataset.find_by(key: dataset_key)
      raise StandardError.new("dataset not found") unless dataset

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

    def add_to_internal_editors(dataset:, netid:)
      current_reviewers = dataset.internal_reviewer_netids || []
      current_editors = dataset.internal_editor_netids || []
      current_can_read = current_reviewers + current_editors
      grant_internal(dataset, netid, :read) unless current_can_read.include?(netid)
      grant_internal(dataset, netid, :view_files) unless current_can_read.include?(netid)
      grant_internal(dataset, netid, :update) unless current_editors.include?(netid)
    end

    def remove_from_internal_editors(dataset:, netid:)
      current_reviewers = dataset.internal_reviewer_netids || []
      current_editors = dataset.internal_editor_netids || []
      revoke_internal(dataset, netid, :read) unless current_reviewers.include?(netid)
      revoke_internal(dataset, netid, :view_files) if current_reviewers.include?(netid)
      revoke_internal(dataset, netid, :update) if current_editors.include?(netid)
    end

    def grant_internal(dataset, netid, ability)
      clean_netid = netid.gsub("@illinois.edu", "")

      existing_record = UserAbility.find_by(resource_type: "Dataset",
                                            resource_id:   dataset.id,
                                            user_provider: "shibboleth",
                                            user_uid:      "#{clean_netid}@illinois.edu",
                                            ability:       ability)
      existing_record ||= UserAbility.create!(resource_type: "Dataset",
                                              resource_id:   dataset.id,
                                              user_provider: "shibboleth",
                                              user_uid:      "#{clean_netid}@illinois.edu",
                                              ability:       ability)
      raise "#{ability} record not created for #{netid}, #{dataset.key}" unless existing_record
    end

    def revoke_internal(dataset, netid, ability)

      clean_netid = netid.gsub("@illinois.edu", "")

      existing_record = UserAbility.find_by(resource_type: "Dataset",
                                            resource_id:   dataset.id,
                                            user_provider: "shibboleth",
                                            user_uid:      "#{clean_netid}@illinois.edu",
                                            ability:       ability)
      existing_record&.destroy
    end

    def scrubbed_netids(input_array=[])
      return input_array if input_array == []
      output_array = Array.new
      input_array.each do |netid|
        output_array << netid.split("@")[0]
      end
      output_array
    end
  end
end
