# frozen_string_literal: true

class GoogleDriveImport < ApplicationRecord
  ACTIVE_STATUSES = ["queued", "importing"].freeze
  STATUSES = (ACTIVE_STATUSES + ["complete", "failed", "cancelled"]).freeze

  belongs_to :user
  belongs_to :dataset
  belongs_to :google_drive_connection
  belongs_to :datafile, optional: true
  validates :status, inclusion: {in: STATUSES}
  before_destroy :remove_staging_file

  def self.ensure_importable!(dataset, user)
    unless user && Ability.new(user).can?(
      :manage, dataset
    )
      raise GoogleDrive::Error,
            "Only curators can import from Google Drive during this pilot."
    end
    if Databank::Application.file_mode == Databank::FileMode::READ_ONLY
      raise GoogleDrive::Error, "File changes are currently disabled."
    end
    unless [Databank::PublicationState::DRAFT, Databank::PublicationState::TempSuppress::VERSION].include?(dataset.publication_state)
      raise GoogleDrive::Error, "Files can only be imported into an editable draft dataset."
    end
  end

  def self.enqueue!(dataset:, user:, connection:, metadata:)
    validate_source = GoogleDrive::Client.validate_metadata!(metadata)
    dataset.with_lock do
      ensure_importable!(dataset, user)
      unless connection.dataset_id == dataset.id && connection.user_id == user.id &&
             connection.expires_at > Time.current && connection.encrypted_credentials.present?
        raise GoogleDrive::Error, "Google authorization is unavailable. Authorize Google Drive again."
      end
      if dataset.datafiles.where(binary_name: metadata.fetch("name")).exists?
        raise GoogleDrive::Error,
              "A file with this name already exists. Rename the Drive file or remove the existing dataset file."
      end

      datafile = dataset.datafiles.create!(binary_name: metadata.fetch("name"),
                                           binary_size: metadata.fetch("size").to_i)
      datafile.update!(storage_key: File.join(datafile.web_id, datafile.binary_name))
      import = create!(dataset: dataset, user: user, google_drive_connection: connection, datafile: datafile,
                       source_metadata: validate_source)
      job = Delayed::Job.enqueue(GoogleDriveImportJob.new(import.id), queue: "google_drive")
      datafile.update!(job_id: job.id)
      import
    end
  end

  def active?
    ACTIVE_STATUSES.include?(status)
  end

  def status_payload
    {id: id, name: source_metadata["name"], size: source_metadata["size"].to_i, status: status,
     bytes_downloaded: bytes_downloaded, error: error_message, datafile_id: datafile&.web_id}
  end

  def self.staging_directory
    configured = IDB_CONFIG.dig(:google, :staging_dir).presence
    return configured.to_s if configured

    File.join((StorageManager.instance.tmpdir.presence || Rails.root.join("tmp")).to_s, "google-drive-imports")
  end

  def staging_path
    File.join(self.class.staging_directory, "#{id}.part")
  end

  def remove_staging_file
    File.delete(staging_path) if File.file?(staging_path)
  end

  def fail!(message)
    update!(status: "failed", error_message: message)
    cleanup_incomplete!
    google_drive_connection.release_if_unused!
  end

  def cleanup_incomplete!
    remove_staging_file
    datafile&.destroy!
    reload
  end

  def cancel_from_datafile!
    return unless active?

    update!(status: "cancelled", error_message: "The dataset file was removed.")
    remove_staging_file
    google_drive_connection.release_if_unused!
  end

  def self.cleanup_expired!
    GoogleDriveConnection.where("expires_at <= ?", Time.current).find_each do |connection|
      connection.google_drive_imports.where(status: ACTIVE_STATUSES).find_each do |import|
        import.fail!("The import authorization expired. Authorize Google Drive and start again.")
      end
      connection.update!(encrypted_credentials: nil)
    end
  end
end
