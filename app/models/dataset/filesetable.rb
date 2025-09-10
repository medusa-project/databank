# frozen_string_literal: true

##
# This module supports computing information about and managing a dataset's set of datafiles.
# It is included in the Dataset model.

module Dataset::Filesetable
  extend ActiveSupport::Concern

  ##
  # @return [Boolean] true if all datafiles in the dataset are in Medusa
  def fileset_preserved?
    # assume all are preserved unless a file is found that is not preserved

    fileset_preserved = true

    datafiles.each do |df|
      fileset_preserved = false if df.storage_root != StorageManager.instance.medusa_root.name
    end

    fileset_preserved
  end

  ##
  # @return [Integer] the total number of bytes in the dataset datafiles
  def total_filesize
    total = 0

    datafiles.each do |datafile|
      total += datafile.bytestream_size
    end

    total
  end

  ##
  # @return [ActiveRecord::Relation] all datafiles that are valid
  # @note it returns datafiles that have a storage_root, storage_key, binary_size, and binary_size > 0
  def valid_datafiles
    datafiles.where.not(storage_root: [nil, ""])
             .where.not(storage_key: [nil, ""])
             .where.not(binary_size: nil)
             .where("binary_size > ?", 0)
  end

  ##
  # @return [ActiveRecord::Relation] sorted dataset datafiles that are valid
  def sorted_valid_datafiles
    basic_sorted = valid_datafiles.sort_by(&:binary_name)
    basic_sorted.select(&:readme?) | basic_sorted # put readme files on top
  end

  ##
  # @return [ActiveRecord::Relation] sorted dataset datafiles
  def sorted_datafiles
    basic_sorted = datafiles.sort_by(&:binary_name)
    basic_sorted.select(&:readme?) | basic_sorted # put readme files on top
  end

  ##
  # @return [ActiveRecord::Relation] all dataset datafiles that are complete
  def complete_datafiles
    return [] if datafiles.count.zero?

    unsorted = datafiles.select(&:upload_complete?)
    return [] if unsorted.count.zero?

    basic_sorted = unsorted.sort_by(&:binary_name)
    basic_sorted.select(&:readme?) | basic_sorted # put readme files on top
  end

  ##
  # @return [ActiveRecord::Relation] all dataset datafiles that are incomplete
  def incomplete_datafiles
    return [] if datafiles.count.zero?

    datafiles.reject(&:upload_complete?).sort_by(&:binary_name)
  end

  ##
  # ensure that all datafiles have previews
  def ensure_previews
    datafiles.each do |datafile|
      if datafile.peek_type.nil?
        datafile.handle_peek
        next
      end

      datafile.handle_peek if datafile.peek_type == Databank::PeekType::NONE
    end
  end

  def ensure_mime_types
    datafiles.each(&:ensure_mime_type)
  end

end
