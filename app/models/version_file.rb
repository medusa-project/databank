# frozen_string_literal: true

# Represents a datafile in a dataset candidate version
# This is used to keep track of the datafiles that are being copied to the new version of the dataset

class VersionFile < ApplicationRecord
  belongs_to :dataset
  validates :datafile_id, uniqueness: true

  # @return [Datafile] the datafile that is being copied
  def source_datafile
    Datafile.find_by_id(datafile_id)
  end

  # @return [Datafile] the datafile that is being copied to
  def target_datafile
    relation = Datafile.where(dataset_id: dataset.id, binary_name: source_datafile.binary_name)
    return nil if relation.count.zero?

    relation.first
  end

  # @return [Boolean] true if the copy process is complete
  def complete?
    td = target_datafile
    return false if td.nil?

    td.exists_on_storage?
  end

  # initiates the copy process
  # @return [Boolean] true if the copy process is initiated
  def copy_file
    return false unless selected

    return true if complete?

    begin
      new_datafile = source_datafile.copy_to_dataset(dataset: dataset)
      return true if new_datafile
    rescue StandardError => e
      update_attribute(:initiated, false)
      raise StandardError.new("Failed to copy version file #{id} | #{e.message}")
    end

    update_attribute(:initiated, false)
    raise StandardError.new("Failed to copy version file #{id} | #{new_datafile.errors.full_messages}")

  end

  # resets the initiated flag
  def reset_copy_file_initiated
    update_attribute(:initiated, false)
  end
end
