# frozen_string_literal: true

##
# Datafile::Versionable
# ------------------
# This module is included in the Datafile model to provide methods for handling datafiles to support versioning datasets

module Datafile::Versionable
  extend ActiveSupport::Concern
  ##
  # Create a copy of this datafile in the given dataset
  # @param [Dataset] dataset the dataset to copy the datafile to
  def copy_to_dataset(dataset:)
    if Datafile.exists?(dataset_id: dataset.id, binary_name: binary_name)
      raise StandardError.new "file with name #{binary_name} already exists in dataset: #{dataset.key}"
    end

    datafile = Datafile.create(dataset_id: dataset.id, binary_name: binary_name)

    StorageManager.instance.draft_root.copy_content_to("#{dataset.key}/#{datafile.binary_name}",
                                                       current_root,
                                                       storage_key)
    datafile.storage_root = "draft"
    datafile.storage_key = "#{dataset.key}/#{datafile.binary_name}"
    datafile.binary_size = StorageManager.instance.draft_root.size(datafile.storage_key)
    datafile.save
  end
end
