# frozen_string_literal: true

module Globusable
  extend ActiveSupport::Concern
  def globus_downloadable?
    Application.storage_manager.globus_download_root.exist?("#{self.key}")
  end
  def globus_download_dir
    "https://app.globus.org/file-manager?origin_id=27efae19-3109-4009-a1ae-1842423b7c92&origin_path=%2Fdemo%2Fdatabank%2Fdownload%2Fidbdev-5230909%2F"
  end
end