# frozen_string_literal: true

require "medusa_storage"

module MedusaStorage::BinaryMultipartUpload
  def copy_io_to_large(key, input_io, md5_sum, metadata = {})
    storage_class = MedusaStorage::Root::S3
    metadata_headers = {}
    metadata_headers[storage_class::AMAZON_HEADERS[:md5_sum]] = md5_sum if md5_sum
    metadata_headers[storage_class::AMAZON_HEADERS[:mtime]] = metadata[:mtime].to_f.to_s if metadata[:mtime]
    object = s3_object(key)
    object_already_exists = object.exists?
    digester = MedusaStorage::EtagCalculator.new(storage_class::AMAZON_PART_SIZE)
    buffer = "".b
    manager = Aws::S3::TransferManager.new(client: s3_client)

    result = manager.upload_stream(bucket: object.bucket_name, key: object.key,
                                   metadata: metadata_headers, part_size: storage_class::AMAZON_PART_SIZE) do |stream|
      # Rails sets a UTF-8 internal encoding; the SDK pipe must not transcode file bytes.
      stream.binmode
      while input_io.read(storage_class::UPLOAD_BUFFER_SIZE, buffer)
        stream << buffer
        digester << buffer
      end
    end
    raise "Unknown error uploading #{key} to storage root #{name}" unless result
    return if object.etag == digester.etag

    object.delete if !object_already_exists && object.exists?
    raise MedusaStorage::Error::MD5
  end
end

MedusaStorage::Root::S3.prepend(MedusaStorage::BinaryMultipartUpload)
