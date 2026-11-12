# frozen_string_literal: true

require "digest"
require "base64"
require "fileutils"

class GoogleDriveImportJob
  # Postgres advisory lock key that limits Drive imports to one at a time across all workers.
  SLOT_LOCK_KEY = 4_727_301_847
  SLOT_RETRY_DELAY = 1.minute
  SPACE_RETRY_DELAY = 10.minutes
  # Free space always left on the staging disk for other server work.
  RESERVE_BYTES = 10_000_000_000

  class Deferred < StandardError
    attr_reader :delay

    def initialize(message, delay)
      super(message)
      @delay = delay
    end
  end

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
    import = GoogleDriveImport.find_by(id: @import_id)
    return unless import&.active?

    with_import_slot { perform_import(import) }
  rescue Deferred => e
    defer!(e.message, e.delay)
  rescue GoogleDrive::RetryableError
    raise
  rescue GoogleDrive::Error => e
    Rails.logger.warn("Google Drive import #{@import_id} stopped: #{e.message}")
    fail_import!(e.message)
  rescue Errno::ENOSPC
    fail_import!("The import worker ran out of staging space. Contact the Research Data Service.")
    Rails.logger.error("Google Drive import #{@import_id}: staging disk full")
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn("Google Drive import #{@import_id} stopped because a required record was removed")
    fail_import!("The dataset, file, or requesting user was removed.")
  end

  def error(_job, exception)
    Rails.logger.error("Google Drive import #{@import_id} attempt failed (#{exception.class})")
    import = GoogleDriveImport.find_by(id: @import_id)
    return unless import&.active?

    import.update!(status: "queued", error_message: "The transfer was interrupted and will retry automatically.")
  end

  def failure(_job)
    fail_import!("The import failed after repeated attempts. Start a new import or contact the Research Data Service.")
  end

  private

  def with_import_slot
    connection = ActiveRecord::Base.connection
    unless connection.select_value("SELECT pg_try_advisory_lock(#{SLOT_LOCK_KEY})")
      raise Deferred.new("Waiting for another Google Drive import to finish.", SLOT_RETRY_DELAY)
    end

    begin
      yield
    ensure
      connection.select_value("SELECT pg_advisory_unlock(#{SLOT_LOCK_KEY})")
    end
  end

  # Re-enqueue rather than retry so waiting does not consume failure attempts.
  # Imports that wait too long are failed by google_drive:cleanup when their authorization expires.
  def defer!(message, delay)
    import = GoogleDriveImport.find_by(id: @import_id)
    return unless import&.active?

    import.update!(status: "queued", error_message: message)
    job = Delayed::Job.enqueue(self.class.new(import.id), queue: "google_drive", run_at: delay.from_now)
    import.datafile&.update!(job_id: job.id)
  end

  def ensure_staging_space!(import, file)
    needed = import.source_metadata.fetch("size").to_i - file.size + RESERVE_BYTES
    available = free_bytes(File.dirname(import.staging_path))
    return if available.nil? || available >= needed

    Rails.logger.warn("Google Drive import #{@import_id} waiting for staging space " \
                      "(#{available} bytes free, #{needed} needed)")
    raise Deferred.new("Waiting for temporary disk space on the server.", SPACE_RETRY_DELAY)
  end

  def free_bytes(directory)
    output = IO.popen(["df", "-Pk", directory], err: File::NULL, &:read)
    return nil unless $?.success?

    Integer(output.lines.last.split[3]) * 1024
  rescue SystemCallError, ArgumentError, NoMethodError
    Rails.logger.warn("Google Drive import #{@import_id} could not check free space in #{directory}")
    nil
  end

  def fail_import!(message)
    import = GoogleDriveImport.find_by(id: @import_id)
    import.fail!(message) if import&.active?
  end

  def perform_import(import)
    GoogleDriveImport.ensure_importable!(import.dataset, import.user)
    client = GoogleDrive::Client.new(import.google_drive_connection)
    verify_source!(client, import)
    import.update!(status: "importing", error_message: nil)
    with_staging_file(import) do |file|
      ensure_staging_space!(import, file)
      download!(client, import, file)
      verify_source!(client, import)
      verify_checksum!(import, file)
      store!(import, file)
    end
    import.remove_staging_file
    import.google_drive_connection.release_if_unused!
  end

  def with_staging_file(import)
    file = open_staging_file(import.staging_path)
    begin
      unless file.flock(File::LOCK_EX | File::LOCK_NB)
        raise GoogleDrive::RetryableError, "Another worker is handling this import."
      end

      yield file
    ensure
      file.close
    end
  end

  # Permission problems are configuration errors; retrying cannot fix them.
  def open_staging_file(path)
    FileUtils.mkdir_p(File.dirname(path), mode: 0o700)
    File.open(path, File::RDWR | File::CREAT, 0o600)
  rescue Errno::EACCES, Errno::EPERM, Errno::EROFS => e
    Rails.logger.error("Google Drive staging directory #{File.dirname(path)} is not writable (#{e.class})")
    raise GoogleDrive::Error, "The import worker cannot write to its staging directory. " \
                              "Contact the Research Data Service."
  end

  def verify_checksum!(import, file)
    checksum = import.source_metadata["md5Checksum"]
    return if checksum.blank?

    file.rewind
    digest = Digest::MD5.new
    buffer = "".b
    digest.update(buffer) while file.read(1.megabyte, buffer)
    return if digest.hexdigest == checksum

    raise GoogleDrive::Error, "The downloaded file failed its checksum check. Start a new import."
  end

  def store!(import, file)
    ensure_active!(import)
    root = StorageManager.instance.draft_root
    storage_key = import.datafile.storage_key
    checksum = import.source_metadata["md5Checksum"]
    checksum = checksum.present? ? Base64.strict_encode64([checksum].pack("H*")) : nil
    file.rewind
    root.copy_io_to(storage_key, file, checksum, file.size)
    import.dataset.with_lock do
      import.with_lock do
        unless import.active? && import.datafile
          raise GoogleDrive::Error, "The import was cancelled."
        end

        GoogleDriveImport.ensure_importable!(import.dataset, import.user.reload)
        unless root.size(storage_key) == file.size
          raise GoogleDrive::Error, "The stored file size does not match the Drive file."
        end
        import.datafile.update!(storage_root: root.name, mime_type: import.source_metadata["mimeType"],
                                upload_status: "uploaded")
        import.update!(status: "complete", error_message: nil)
      end
    end
  ensure
    if root && storage_key && !GoogleDriveImport.where(id: @import_id, status: "complete").exists? && root.exist?(storage_key)
      root.delete_content(storage_key)
    end
  end

  def verify_source!(client, import)
    current = GoogleDrive::Client.validate_metadata!(client.metadata(import.source_metadata.fetch("id")))
    fields = ["id", "name", "size", "version", "md5Checksum"]
    return if current.slice(*fields) == import.source_metadata.slice(*fields)

    raise GoogleDrive::Error, "The file changed in Google Drive. Select it again to import the current version."
  end

  def download!(client, import, file)
    offset = [file.size, import.bytes_downloaded].min
    file.truncate(offset)
    file.seek(offset)
    import.update!(bytes_downloaded: offset)
    size = import.source_metadata.fetch("size").to_i
    while offset < size
      ensure_active!(import)
      chunk = client.chunk(import.source_metadata, offset)
      file.write(chunk)
      file.flush
      file.fsync
      offset += chunk.bytesize
      import.update!(bytes_downloaded: offset)
    end
  end

  def ensure_active!(import)
    import.reload
    raise GoogleDrive::Error, "The import was cancelled." unless import.active? && import.datafile

    GoogleDriveImport.ensure_importable!(import.dataset.reload, import.user.reload)
  end
end
