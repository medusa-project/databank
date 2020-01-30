# frozen_string_literal: true

module Globusable
  extend ActiveSupport::Concern
  def globus_downloadable?
    return false unless self.publication_state == Databank::PublicationState::RELEASED

    self.datafiles.each do |datafile|
      return false unless Application.storage_manager.globus_download_root.exist?("#{self.key}/#{datafile.binary_name}")

    end
    true
  end
  def globus_download_dir
    if Rails.env.demo? || Rails.env.production?
      "#{GLOBUS_CONFIG[:download_url_base]}#{self.key}"
    else
      "https://app.globus.org"
    end

  end

  def globus_ingest_dir
    if Rails.env.demo? || Rails.env.production?
      "#{GLOBUS_CONFIG[:ingest_url_base]}#{self.key}"
    else
      "https://app.globus.org"
    end
  end

  def import_from_globus
    raise "invalid environment, must be demo or production" unless Rails.env.demo? || Rails.env.production?
    raise "files not found on Globus endpoint" unless Application.storage_manager.globus_ingest_root.exist?("#{self.key}/")
    storage_keys = Application.storage_manager.globus_ingest_root.file_keys(self.key)
    storage_keys.each do |storage_key|
      key_parts = storage_key.split("/")
      name_part = key_parts.last
      obj_size = Application.storage_manager.draft_root.size(storage_key)
      Datafile.create(dataset_id: self.id,
                      binary_name: name_part,
                      binary_size: obj_size,
                      storage_root: 'draft',
                      storage_key: storage_key)

    end

  end

  def remove_from_globus_download
    return nil unless Rails.env.demo? || Rails.env.production?
    return nil unless Application.storage_manager.globus_download_root.exist?("#{self.key}/")
    storage_keys = Application.storage_manager.globus_download_root.file_keys(self.key)
    storage_keys.each do |storage_key|
      Application.storage_manager.globus_download_root.delete_content(storage_key)
    end
    Application.storage_manager.globus_download_root.delete_content("#{self.key}/")
  end

end