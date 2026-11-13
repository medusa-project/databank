# frozen_string_literal: true

class BoxImport < ApplicationRecord
  ACTIVE_STATUSES = CloudImports::ACTIVE_STATUSES
  STATUSES = CloudImports::STATUSES
  belongs_to :user
  belongs_to :dataset
  belongs_to :box_connection
  belongs_to :datafile, optional: true
  validates :status, inclusion: {in: STATUSES}
  before_destroy :abort_s3_upload!

  def self.ensure_importable!(dataset, user)
    CloudImports.ensure_importable!(dataset, user, provider: "Box")
    unless StorageManager.instance.draft_root.is_a?(MedusaStorage::Root::S3)
      raise BoxStorage::Error, "Box imports require S3-backed draft storage."
    end
  end

  def self.enqueue!(dataset:, user:, connection:, metadata:)
    metadata = BoxStorage::Client.validate_metadata!(metadata)
    dataset.with_lock do
      ensure_importable!(dataset, user)
      if dataset.box_imports.where(status: ACTIVE_STATUSES).exists?
        raise BoxStorage::Error, "A Box import is already queued or in progress for this dataset."
      end
      unless connection.dataset_id == dataset.id && connection.user_id == user.id &&
             connection.expires_at > Time.current && connection.encrypted_credentials.present?
        raise BoxStorage::Error, "Box authorization is unavailable. Authorize Box again."
      end
      if dataset.datafiles.where(binary_name: metadata.fetch("name")).exists?
        raise BoxStorage::Error, "A file with this name already exists. Rename the Box file or remove the dataset file."
      end
      datafile = dataset.datafiles.create!(binary_name: metadata.fetch("name"),
                                           binary_size: metadata.fetch("size").to_i)
      datafile.update!(storage_key: File.join(datafile.web_id, datafile.binary_name))
      import = create!(dataset: dataset, user: user, box_connection: connection, datafile: datafile,
                       source_metadata: metadata)
      job = Delayed::Job.enqueue(BoxImportJob.new(import.id), queue: "box")
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

  def fail!(message)
    update!(status: "failed", error_message: message)
    cleanup_incomplete!
    box_connection.release_if_unused!
  end

  def cleanup_incomplete!
    abort_s3_upload!
    datafile&.destroy!
    reload
  end

  def cancel_from_datafile!
    return unless active?

    update!(status: "cancelled", error_message: "The dataset file was removed.")
    abort_s3_upload!
    box_connection.release_if_unused!
  end

  def abort_s3_upload!
    return if s3_upload_id.blank?

    CloudImports::S3MultipartUpload.new(self, StorageManager.instance.draft_root, provider: "Box").abort!
  end

  def self.cleanup_expired!
    BoxConnection.where("expires_at <= ?", Time.current).find_each do |connection|
      connection.box_imports.where(status: ACTIVE_STATUSES).find_each do |import|
        import.fail!("The Box import authorization expired. Authorize Box and start again.")
      end
      connection.update!(encrypted_credentials: nil)
    end
  end
end
