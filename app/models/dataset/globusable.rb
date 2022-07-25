# frozen_string_literal: true

require "net/http"
require "aws-sdk-s3"

module Dataset::Globusable
  extend ActiveSupport::Concern
  def globus_downloadable?
    return false unless publication_state == Databank::PublicationState::RELEASED

    begin
      datafiles.each do |datafile|
        return false unless StorageManager.instance.globus_download_root.exist?("#{key}/#{datafile.binary_name}")
      end
    rescue StandardError => e
      Rails.logger.warn("Error #{e.message} attempting to check if dataset available in Globus: #{key}")
      return false
    end

    true
  end

  def globus_download_dir
    if Rails.env.demo? || Rails.env.production?
      "#{GLOBUS_CONFIG[:download_url_base]}#{key}"
    else
      "https://app.globus.org"
    end
  end

  def ensure_globus_ingest_dir
    return nil unless Rails.env.demo? || Rails.env.production?

    return true if StorageManager.instance.globus_ingest_root.exist?("#{key}/")

    return nil unless IDB_CONFIG[:aws][:s3_mode] == true

    bucket = Rails.application.credentials[:storage][:draft_bucket]
    prefix = Rails.application.credentials[:storage][:draft_prefix]
    dir_key = "#{prefix}/#{key}/"
    client = Application.aws_client
    client.put_object(bucket: bucket, key: dir_key)
    StorageManager.instance.globus_ingest_root.exist?("#{key}/")
  end

  def globus_ingest_dir
    if Rails.env.demo? || Rails.env.production?
      "#{GLOBUS_CONFIG[:ingest_url_base]}#{key}"
    else
      "https://app.globus.org"
    end
  end

  def import_from_globus
    raise "invalid environment, must be demo or production" unless Rails.env.demo? || Rails.env.production?
    raise "files not found on Globus endpoint" unless StorageManager.instance.globus_ingest_root.exist?("#{key}/")

    storage_keys = StorageManager.instance.globus_ingest_root.file_keys(key)
    storage_keys.each do |storage_key|
      key_parts = storage_key.split("/")
      name_part = key_parts.last
      existing_datafile = Datafile.find_by(dataset_id: id, binary_name: name_part)
      next if existing_datafile

      obj_size = StorageManager.instance.draft_root.size(storage_key)

      mime_guesses_set = MIME::Types.type_for(name_part.downcase)
      mime_guess = if mime_guesses_set && !mime_guesses_set.length.positive?
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
    return nil unless Rails.env.demo? || Rails.env.production?
    return nil unless StorageManager.instance.globus_download_root.exist?("#{key}/")

    storage_keys = StorageManager.instance.globus_download_root.file_keys(key)
    storage_keys.each do |storage_key|
      StorageManager.instance.globus_download_root.delete_content(storage_key)
    end
    StorageManager.instance.globus_download_root.delete_content("#{key}/")
  end

  def remove_globus_ingest_dir
    return nil unless Rails.env.demo? || Rails.env.production?

    return nil unless StorageManager.instance.globus_ingest_root.exist?("#{key}/")

    storage_keys = StorageManager.instance.globus_ingest_root.file_keys(key)
    storage_keys.each do |storage_key|
      StorageManager.instance.globus_ingest_root.delete_content(storage_key)
    end
    StorageManager.instance.globus_ingest_root.delete_content("#{key}/")
  end
end
