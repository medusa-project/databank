# frozen_string_literal: true

##
# Datafile::Storable
# ------------------
# This module is included in the Datafile model to provide methods for handling the storage of the datafile

module Datafile::Storable
  extend ActiveSupport::Concern
  ##
  # @return [MedusaStorageRoot] the datafile's storage root
  def current_root
    StorageManager.instance.root_set.at(storage_root)
  end

  ##
  # @return [MedusaStorageRoot] the StorageManager's temporary filesystem root
  def tmpfs_root
    StorageManager.instance.tmpfs_root
  end

  ##
  # @return [String] the name of the datafile's storage root bucket
  def storage_root_bucket
    current_root.bucket if IDB_CONFIG[:aws][:s3_mode]
  end

  ##
  # @return [String] the datafile's storage key with the root's prefix
  def storage_key_with_prefix
    if IDB_CONFIG[:aws][:s3_mode]
      "#{current_root.prefix}#{storage_key}"
    else
      storage_key
    end
  end

  ##
  # @return [String] the datafile's storage path if the storage root is a filesystem root
  def storage_root_path
    if IDB_CONFIG[:aws][:s3_mode]
      nil
    else
      current_root&.real_path
    end
  end

  ##
  # If the datafile is in a filesystem root, returns the full path to the datafile
  # @return [String] the datafile's full path
  def filepath
    base = storage_root_path
    if base
      File.join(base, storage_key)
    else
      raise StandardError.new("no filesystem path found for datafile: #{self.web_id}")
    end
  end

  ##
  # Whether the datafile is in Medusa
  # Actually checks the storage, not just the database records
  # has side-effect of updating record if the bytestream is in Medusa, but the record did not indicate
  # if bytestream is found the same in draft and medusa roots, the draft bytestream is deleted
  # @return [Boolean] whether the datafile is in Medusa
  def in_medusa
    Rails.logger.warn("dataset not found for datafile #{self.web_id} :in_medusa") unless dataset
    return false unless dataset

    return false unless dataset.identifier && dataset.identifier != ""

    datafile_in_medusa = StorageManager.instance.medusa_root.exist?(target_key)
    # Rails.logger.warn "datafile_in_medusa: #{datafile_in_medusa} for #{target_key}"
    if datafile_in_medusa
      if storage_root && storage_key && storage_root == "draft" && storage_key != ""

        # If the binary object also exists in draft system, delete duplicate.
        #  Can't do full equivalence check (S3 etag is not always MD5), so check sizes.
        if StorageManager.instance.draft_root.exist?(storage_key)
          draft_size = StorageManager.instance.draft_root.size(storage_key)
          medusa_size = StorageManager.instance.medusa_root.size(target_key)

          if draft_size == medusa_size
            # If the ingest into Medusa was successful,
            # delete redundant binary object
            # and update Illinois Data Bank datafile record
            StorageManager.instance.draft_root.delete_content(storage_key)
            datafile_in_medusa = true
          else
            datafile_in_medusa = false
            exception_string("Different size draft vs medusa. Dataset: #{dataset.key}, Datafile: #{datafile.web_id}")
            notification = DatabankMailer.error(exception_string)
            notification.deliver_now
          end
        else
          datafile_in_medusa = true
        end
      else
        datafile_in_medusa = true
      end

      if datafile_in_medusa
        self.storage_root = "medusa"
        self.storage_key = target_key
        save!
      end
    end
    datafile_in_medusa
  end

  ##
  # Does this dataset have a stored binary object?
  # @return [Boolean] whether the datafile object bytestream is in the draft storage root
  def bytestream?
    storage_root &&
      storage_root != "" &&
      storage_key &&
      storage_key != "" &&
      current_root.exist?(storage_key)
  end

  ##
  # Removes the datafile's binary object from the draft storage root
  def remove_binary
    return nil unless storage_key

    if StorageManager.instance.draft_root.exist?(storage_key)
      StorageManager.instance.draft_root.delete_content(storage_key)
    end

    return nil unless StorageManager.instance.draft_root.exist?("#{storage_key}.info")

    StorageManager.instance.draft_root.delete_content("#{storage_key}.info")
  end

  ##
  # Set this up so that we use local storage for small files, for some definition of small
  # might want to extract this elsewhere so that is generally available and easy to make
  # robust for whatever application.
  # @return [String] the datafile's mime type
  def tmpdir_for_with_input_file
    expected_size = binary_size || current_root.size(storage_key)
    if expected_size > 500.megabytes
      StorageManager.instance.tmpdir
    else
      Dir.tmpdir
    end
  end

  ##
  # wrap the storage root's ability to yield an io on the content
  def with_input_io
    current_root.with_input_io(storage_key) do |io|
      yield io
    end
  end

  ##
  # wrap the storage root's ability to yield a file path having the appropriate content in it
  def with_input_file
    current_root.with_input_file(storage_key, tmp_dir: tmpdir_for_with_input_file) do |file|
      yield file
    end
  end

  ##
  # @return [Boolean] whether the datafile exists on its storage root
  def exists_on_storage?
    return false unless storage_key

    current_root.exist?(storage_key)
  end

  ##
  # Remove the datafile from its storage root
  def remove_from_storage
    current_root.delete_content(storage_key) if exists_on_storage?
  end

  ##
  # @return [String] a key to use for temporary storage of the datafile
  # derived from the dataset's key and the datafile's name
  def tmpfs_key
    File.join(dataset.key, name)
  end

  ##
  # copy the datafile to the temporary filesystem storage
  # could be used for staging small files for download
  def copy_to_tmpfs
    raise StandardError.new "file at #{tmpfs_key} already exists" if tmpfs_root.exist?(tmpfs_key)

    with_input_io do |input_io|
      tmpfs_root.copy_io_to(tmpfs_key, input_io, nil, binary_size)
    end
  end

  ##
  # Remove the datafile from the temporary filesystem storage
  def remove_from_tmpfs
    return true unless tmpfs_root.exist?(tmpfs_key)

    tmpfs_root.delete_content(tmpfs_key)
    tmpfs_root.delete_tree(dataset.key) if Dir.empty?(File.join(tmpfs_root.real_path, dataset.key))
  end

end
