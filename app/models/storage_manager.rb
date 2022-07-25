# frozen_string_literal: true

require 'singleton'

class StorageManager
  include Singleton
  attr_accessor :draft_root,
                :medusa_root,
                :message_root,
                :tmpfs_root,
                :globus_download_root,
                :globus_ingest_root,
                :root_set,
                :tmpdir

  def initialize
    storage_config = STORAGE_CONFIG[:storage].map(&:to_h)
    self.root_set = MedusaStorage::RootSet.new(storage_config)
    self.draft_root = root_set.at("draft")
    self.medusa_root = root_set.at("medusa")
    self.message_root = root_set.at("message")
    self.tmpfs_root = root_set.at("tmpfs")
    if Rails.env.production? || Rails.env.demo?
      self.globus_download_root = root_set.at("globus_download")
      self.globus_ingest_root = root_set.at("globus_ingest")
    end
    initialize_tmpdir
  end

  def initialize_tmpdir
    self.tmpdir = IDB_CONFIG[:storage_tmpdir]
  end
end
