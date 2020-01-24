# frozen_string_literal: true

module Globusable
  extend ActiveSupport::Concern
  def globus_downloadable?
    return false unless self.publication_state == Databank::PublicationState::RELEASED
    self.datafiles.each do |datafile|
      return false unless Application.storage_manager.globus_download_root.exist?("#{self.key}/#{datafile.binary_name}")
    end
    return true
  end
  def globus_download_dir
    if Rails.env.demo?
      "https://app.globus.org/file-manager?origin_id=27efae19-3109-4009-a1ae-1842423b7c92&origin_path=%2Fdemo%2Fdatabank%2Fdownload%2F#{self.key}"
    elsif Rails.env.production?
      "https://app.globus.org/file-manager?origin_id=27efae19-3109-4009-a1ae-1842423b7c92&origin_path=%2Fproduction%2Fdatabank%2Fdownload%2F#{self.key}"
    else
      "https://app.globus.org"
    end

  end
end