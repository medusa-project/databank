# frozen_string_literal: true

class CloudImports::S3MultipartUpload
  PART_BYTES = CloudImports::CHUNK_BYTES

  def initialize(import, root, provider: "Google Drive")
    @import = import
    @provider = provider
    @metadata_key = provider == "Box" ? "box-import-id" : "google-drive-import-id"
    @client = root.s3_client
    @bucket = root.bucket
    @key = root.s3_object(import.datafile.storage_key).key
  end

  def upload!(drive_client)
    return if completed_object?

    ensure_upload!
    parts = normalized_parts
    digest = @import.source_metadata["sha1"].present? ? Digest::SHA1.new : Digest::MD5.new
    etag_calculator = MedusaStorage::EtagCalculator.new(PART_BYTES)
    offset = verify_saved_parts!(drive_client, parts, digest, etag_calculator)
    upload_remaining_parts!(drive_client, parts, digest, etag_calculator, offset)
    verify_source_checksum!(digest)

    yield if block_given?
    @import.with_lock do
      ensure_active!
      complete!(parts, etag_calculator.etag)
    end
  end

  def abort!
    upload_id = @import.s3_upload_id
    return if upload_id.blank?

    @client.abort_multipart_upload(bucket: @bucket, key: @key, upload_id: upload_id)
    @import.update!(s3_upload_id: nil, s3_uploaded_parts: [])
  rescue Aws::S3::Errors::NoSuchUpload
    delete_completed_object!
    @import.update!(s3_upload_id: nil, s3_uploaded_parts: [])
  rescue Aws::S3::Errors::ServiceError => e
    Rails.logger.error("Could not clean up #{@provider} S3 upload #{@import.id}: #{e.class}")
    raise
  end

  private

  def verify_saved_parts!(drive_client, parts, digest, etag_calculator)
    offset = 0
    parts.each_with_index do |part, index|
      unless part.fetch("part_number").to_i == index + 1
        raise CloudImports::Error, "The saved S3 multipart upload is incomplete. Start a new import."
      end

      chunk = drive_client.chunk(@import.source_metadata, offset)
      unless chunk.bytesize == part_size(offset) && chunk.bytesize == part.fetch("size").to_i &&
             Digest::MD5.base64digest(chunk) == part.fetch("md5")
        raise CloudImports::Error, "A previously uploaded part no longer matches the #{@provider} file."
      end

      digest.update(chunk)
      etag_calculator << chunk
      offset += chunk.bytesize
    end
    offset
  end

  def upload_remaining_parts!(drive_client, parts, digest, etag_calculator, offset)
    while offset < file_size
      ensure_active!
      chunk = drive_client.chunk(@import.source_metadata, offset)
      upload_part!(parts, chunk)
      digest.update(chunk)
      etag_calculator << chunk
      offset += chunk.bytesize
    end
  end

  def upload_part!(parts, chunk)
    part_number = parts.length + 1
    response = @client.upload_part(
      bucket: @bucket, key: @key, upload_id: @import.s3_upload_id,
      part_number: part_number, body: chunk
    )
    part = {
      "part_number" => part_number,
      "etag"        => response.etag,
      "md5"         => Digest::MD5.base64digest(chunk),
      "size"        => chunk.bytesize
    }
    @import.with_lock do
      ensure_active!
      persisted_parts = normalized_parts
      unless part_number == persisted_parts.length + 1
        raise CloudImports::RetryableError, "The multipart upload changed. The import will retry."
      end

      @import.update!(s3_uploaded_parts: persisted_parts + [part],
                      bytes_downloaded:  @import.bytes_downloaded + chunk.bytesize)
    end
    parts << part
    part
  end

  def verify_source_checksum!(digest)
    expected_checksum = @import.source_metadata["sha1"].presence || @import.source_metadata["md5Checksum"]
    return if expected_checksum.blank? || digest.hexdigest.casecmp?(expected_checksum)

    raise CloudImports::Error, "The downloaded file failed its checksum check. Start a new import."
  end

  def ensure_upload!
    return if @import.s3_upload_id.present?

    metadata = {@metadata_key => @import.id.to_s}
    checksum = @import.source_metadata["md5Checksum"]
    metadata["md5chksum"] = Base64.strict_encode64([checksum].pack("H*")) if checksum.present?
    response = @client.create_multipart_upload(bucket: @bucket, key: @key, metadata: metadata)
    @import.with_lock do
      ensure_active!
      @import.update!(s3_upload_id: response.upload_id, s3_uploaded_parts: [], bytes_downloaded: 0)
    end
  rescue StandardError
    cleanup_unrecorded_upload(response.upload_id) if response&.upload_id
    raise
  end

  def cleanup_unrecorded_upload(upload_id)
    @client.abort_multipart_upload(bucket: @bucket, key: @key, upload_id: upload_id)
  rescue Aws::S3::Errors::ServiceError => e
    Rails.logger.error("Could not clean up unrecorded #{@provider} S3 upload #{@import.id}: #{e.class}")
  end

  def complete!(parts, expected_etag)
    @client.complete_multipart_upload(
      bucket: @bucket, key: @key, upload_id: @import.s3_upload_id,
      multipart_upload: {parts: parts.map {|part| {part_number: part.fetch("part_number"), etag: part.fetch("etag")} }}
    )
    verify_completed_object!(expected_etag)
  end

  def verify_completed_object!(expected_etag)
    head = @client.head_object(bucket: @bucket, key: @key)
    unless head.content_length == file_size && head.metadata[@metadata_key] == @import.id.to_s &&
           head.etag == expected_etag
      raise CloudImports::Error, "The S3 copy could not be verified. Start a new import."
    end
  end

  def completed_object?
    head = @client.head_object(bucket: @bucket, key: @key)
    head.content_length == file_size && head.metadata[@metadata_key] == @import.id.to_s &&
      head.etag == etag_from_saved_parts
  rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchKey
    false
  end

  def delete_completed_object!
    head = @client.head_object(bucket: @bucket, key: @key)
    return unless head.metadata[@metadata_key] == @import.id.to_s

    @client.delete_object(bucket: @bucket, key: @key)
  rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchKey
    nil
  end

  def normalized_parts
    (@import.s3_uploaded_parts || []).sort_by {|part| part.fetch("part_number").to_i }
  end

  def etag_from_saved_parts
    parts = normalized_parts
    return if parts.empty?

    binary_digests = parts.map {|part| Base64.decode64(part.fetch("md5")) }.join
    %("#{Digest::MD5.hexdigest(binary_digests)}-#{parts.length}")
  end

  def file_size
    @import.source_metadata.fetch("size").to_i
  end

  def part_size(offset)
    [PART_BYTES, file_size - offset].min
  end

  def ensure_active!
    @import.reload
    raise CloudImports::Error, "The import was cancelled." unless @import.active? && @import.datafile
  end
end
