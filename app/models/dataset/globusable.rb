# frozen_string_literal: true

##
# This module provides methods for checking if a dataset is available for download from Globus,
# and for importing a dataset from Globus.
# It also provides methods for removing a dataset from the Globus download directory
# and for removing the Globus ingest directory.
# This module is included in the Dataset model.

require "mime/types"
require "net/http"
require "aws-sdk-s3"

module Dataset::Globusable
  extend ActiveSupport::Concern

  def copy_to_globus_ingest_dir(source_root_name:, source_key:, target_name_override: nil)
    source_root = StorageManager.instance.root_set.at(source_root_name)
    raise StandardError.new "source directory not found" unless source_root.exist?(source_key)

    raise StandardError.new "unable to ensure globus ingest directory" unless ensure_globus_ingest_dir

    target_name = target_name_override || source_key.split("/").last
    target_key = "#{self.key}/#{target_name}"

    StorageManager.instance.globus_ingest_root.copy_content_to(target_key, source_root, source_key)
  end


  def globus_downloadable?
    return false unless publication_state == Databank::PublicationState::RELEASED

    return true if all_globus == true

    false
  end

  def globus_download_dir
    "#{GLOBUS_CONFIG[:download_url_base]}#{key}"
  end

  def ensure_globus_ingest_dir
    root = StorageManager.instance.draft_root
    prefix = root.prefix
    dir_key = "#{prefix}#{root.ensure_directory_key(key)}"
    return true if StorageManager.instance.globus_ingest_root.exist?("#{key}/")

    return nil unless IDB_CONFIG[:aws][:s3_mode] == true || IDB_CONFIG[:aws][:s3_mode] == "local"

    bucket = root.s3_bucket.name
    client = root.s3_client
    client.put_object({bucket: bucket, key: dir_key})
    StorageManager.instance.globus_ingest_root.exist?("#{key}/")
  end

  def globus_ingest_dir
    "#{GLOBUS_CONFIG[:ingest_url_base]}#{key}"
  end

  def import_from_globus
    raise "files not found on Globus endpoint" unless StorageManager.instance.globus_ingest_root.exist?("#{key}/")

    storage_keys = StorageManager.instance.globus_ingest_root.file_keys(key)
    storage_keys.each do |storage_key|
      key_parts = storage_key.split("/")
      name_part = key_parts.last
      existing_datafile = Datafile.find_by(dataset_id: id, binary_name: name_part)
      next if existing_datafile

      obj_size = StorageManager.instance.draft_root.size(storage_key)

      mime_guesses_set = MIME::Types.type_for(name_part.downcase)
      mime_guess = if mime_guesses_set&.length&.positive?
                     mime_guesses_set[0].content_type
                   else
                     "application/octet-stream"
                   end
      Datafile.create(dataset_id:   id,
                      binary_name:  name_part,
                      binary_size:  obj_size,
                      mime_type:    mime_guess,
                      storage_root: "draft",
                      storage_key:  storage_key)
    end
  end

  def remove_from_globus_download

    return true unless StorageManager.instance.globus_download_root.exist?("#{key}/")

    storage_keys = StorageManager.instance.globus_download_root.file_keys(key)
    storage_keys.each do |storage_key|
      StorageManager.instance.globus_download_root.delete_content(storage_key)
    end
    # set in_globus to false for all datafiles in dataset
    Datafile.where(dataset_id: id).update_all(in_globus: false)
    # set all_globus to false for dataset
    update(all_globus: false)
    StorageManager.instance.globus_download_root.delete_content("#{key}/")

  end

  def delete_from_globus_ingest_dir(storage_key:)
    return nil unless StorageManager.instance.globus_ingest_root.exist?(storage_key)

    target_key = "#{self.key}/#{storage_key}"
    StorageManager.instance.globus_ingest_root.delete_content(target_key)
  end

  def remove_globus_ingest_dir
    return nil unless StorageManager.instance.globus_ingest_root.exist?("#{key}/")

    storage_keys = StorageManager.instance.globus_ingest_root.file_keys(key)
    storage_keys.each do |storage_key|
      StorageManager.instance.globus_ingest_root.delete_content(storage_key)
    end
    StorageManager.instance.globus_ingest_root.delete_content("#{key}/")
  end
end
