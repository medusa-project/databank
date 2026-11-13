# frozen_string_literal: true

class BoxImportJob
  def initialize(import_id)
    @import_id = import_id
  end

  def max_attempts
    3
  end

  def max_run_time
    3.hours
  end

  def perform
    import = BoxImport.find_by(id: @import_id)
    return unless import&.active?

    unless CloudImports::TransferSlot.synchronize { perform_import(import) }
      import.with_lock do
        if import.active?
          import.update!(status: "queued", error_message: "Waiting for another cloud import to finish.")
          job = Delayed::Job.enqueue(self.class.new(import.id), queue: "box", run_at: 1.minute.from_now)
          import.datafile&.update!(job_id: job.id)
        end
      end
    end
  rescue BoxStorage::RetryableError, CloudImports::RetryableError
    raise
  rescue CloudImports::Error => e
    Rails.logger.warn("Box import #{@import_id} stopped: #{e.message}")
    fail_import!(e.message)
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn("Box import #{@import_id} stopped because a required record was removed")
    fail_import!("The dataset, file, or requesting user was removed.")
  end

  def error(_job, exception)
    Rails.logger.error("Box import #{@import_id} attempt failed (#{exception.class})")
    import = BoxImport.find_by(id: @import_id)
    return unless import&.active?

    import.update!(status: "queued", error_message: "The transfer was interrupted and will retry automatically.")
  end

  def failure(_job)
    fail_import!("The import failed after repeated attempts. Start a new import or contact the Research Data Service.")
  end

  private

  def perform_import(import)
    BoxImport.ensure_importable!(import.dataset, import.user)
    client = BoxStorage::Client.new(import.box_connection)
    verify_source!(client, import)
    import.with_lock do
      raise BoxStorage::Error, "The import was cancelled." unless import.active? && import.datafile

      import.update!(status: "importing", error_message: nil)
    end
    root = StorageManager.instance.draft_root
    CloudImports::S3MultipartUpload.new(import, root, provider: "Box").upload!(client) do
      verify_source!(client, import)
      BoxImport.ensure_importable!(import.dataset.reload, import.user.reload)
    end
    import.dataset.with_lock do
      import.with_lock do
        raise BoxStorage::Error, "The import was cancelled." unless import.active? && import.datafile

        BoxImport.ensure_importable!(import.dataset, import.user.reload)
        import.datafile.update!(storage_root: root.name, mime_type: import.source_metadata["mimeType"],
                                upload_status: "uploaded")
        import.update!(status: "complete", error_message: nil, s3_upload_id: nil, s3_uploaded_parts: [])
      end
    end
    import.box_connection.release_if_unused!
  end

  def verify_source!(client, import)
    current = BoxStorage::Client.validate_metadata!(client.metadata(import.source_metadata.fetch("id")))
    fields = ["id", "name", "size", "version", "sha1"]
    return if current.slice(*fields) == import.source_metadata.slice(*fields)

    raise BoxStorage::Error, "The file changed in Box. Select it again to import the current version."
  end

  def fail_import!(message)
    import = BoxImport.find_by(id: @import_id)
    import.fail!(message) if import&.active?
  end
end
