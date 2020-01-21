class StorageManager

  attr_accessor :draft_root, :medusa_root, :globus_download_root, :globus_ingest_root, :root_set, :tmpdir

  def initialize

    storage_config = STORAGE_CONFIG[:storage].collect(&:to_h)
    self.root_set = MedusaStorage::RootSet.new(storage_config)
    self.draft_root = self.root_set.at('draft')
    self.medusa_root = self.root_set.at('medusa')
    if Rails.env.aws_production? || Rails.env.aws_demo?
      self.globus_download_root = self.root_set.at("globus_download")
      self.globus_ingest_root = self.root_set.at("globus_ingest")
    end
    initialize_tmpdir

  end

  def initialize_tmpdir
    self.tmpdir = IDB_CONFIG[:storage_tmpdir]
  end

end
