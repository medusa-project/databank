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

  def ingest_from_globus
    raise "invalid environment, must be demo or production" unless Rails.env.demo? || Rails.env.production?



  end

end