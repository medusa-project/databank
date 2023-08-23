class VersionFile < ApplicationRecord
  belongs_to :dataset
  def source_datafile
    Datafile.find_by_id(datafile_id)
  end

  def target_datafile
    relation = Datafile.where(dataset_id: dataset.id, filename: filename)
    return nil if relation.count.zero?

    relation.first
  end

  def complete?
    td = target_datafile

    return false if td.blank?

    return false unless td.bytestream_size

    td.bytestream_size == source_datafile.bytestream_size
  end

  def copy_file
    return false unless selected

    return true if complete?

    raise "already initiated" if initiated

    begin
      update_attribute(:initiated, true)
      new_datafile = source_datafile.copy_to_dataset(dataset: dataset)
      return true if new_datafile
    rescue StandardError => e
      update_attribute(:initiated, false)
      raise StandardError.new("Failed to copy version file #{self.id} | #{e.message}")
    end

    update_attribute(:initiated, false)
    raise StandardError.new("Failed to copy version file #{self.id} | #{new_datafile.errors.full_messages}")

  end

  def reset_copy_file_initiated
    update_attribute(:initiated, false)
  end
end
