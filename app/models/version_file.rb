class VersionFile < ApplicationRecord
  belongs_to :dataset
  validates :datafile_id, uniqueness: true

  def source_datafile
    Datafile.find_by_id(datafile_id)
  end

  def target_datafile
    relation = Datafile.where(dataset_id: dataset.id, binary_name: source_datafile.binary_name)
    return nil if relation.count.zero?

    relation.first
  end

  def complete?
    td = target_datafile
    return false if td.nil?

    td.exists_on_storage?
  end

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

  def reset_copy_file_initiated
    update_attribute(:initiated, false)
  end
end
