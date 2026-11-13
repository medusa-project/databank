# frozen_string_literal: true

require "rails_helper"

RSpec.describe GoogleDriveImportJob do
  include GoogleDriveHelpers

  let(:user) { create(:user, :admin) }
  let(:dataset) { create(:dataset) }
  let(:connection) { create_drive_connection(user: user, dataset: dataset) }
  let(:import) { GoogleDriveImport.enqueue!(dataset: dataset, user: user, connection: connection, metadata: drive_metadata) }
  let(:client) { instance_double(GoogleDrive::Client) }
  let(:job) { described_class.new(import.id) }
  let(:draft_root) { MedusaStorage::Root::Filesystem.new(name: "drive-test", path: @storage_directory) }

  around do |example|
    Dir.mktmpdir("drive-import-spec") do |directory|
      @storage_directory = directory
      example.run
    end
  end

  before do
    dataset
    connection
    allow(StorageManager.instance).to receive(:tmpdir).and_return(@storage_directory)
    allow(StorageManager.instance).to receive(:draft_root).and_return(draft_root)
    allow(GoogleDrive::Client).to receive(:new).with(connection).and_return(client)
    allow(client).to receive(:metadata).and_return(drive_metadata)
    allow(client).to receive(:chunk).with(drive_metadata, 0).and_return("hello")
  end

  it "copies verified bytes to filesystem storage and persists completion" do
    job.perform
    expect(import.reload.status).to eq("complete")
    expect(import.bytes_downloaded).to eq(5)
    expect(draft_root.path_to(import.datafile.storage_key).binread).to eq("hello")
    expect(import.datafile.reload.storage_root).to eq("drive-test")
    expect(connection.reload.encrypted_credentials).to be_nil
    expect(File.exist?(import.staging_path)).to be(false)
  end

  it "stores binary bytes that are not valid UTF-8 unchanged" do
    content = "%PDF-\xB5\xFF\x00\xE2".b
    metadata = drive_metadata(content)
    binary_import = GoogleDriveImport.enqueue!(dataset: dataset, user: user, connection: connection, metadata: metadata)
    allow(client).to receive(:metadata).and_return(metadata)
    allow(client).to receive(:chunk).with(metadata, 0).and_return(content)
    expect(Encoding.default_internal).to eq(Encoding::UTF_8)
    described_class.new(binary_import.id).perform
    expect(binary_import.reload.status).to eq("complete")
    expect(draft_root.path_to(binary_import.datafile.storage_key).binread).to eq(content)
  end

  it "passes a binary IO, base64 checksum, and exact size to the storage adapter" do
    expect(draft_root).to receive(:copy_io_to).with(import.datafile.storage_key, kind_of(File),
                                                  Digest::MD5.base64digest("hello"), 5).and_call_original
    job.perform
    expect(import.reload.status).to eq("complete")
  end

  it "copies through the real S3 adapter with the SDK's network responses stubbed" do
    s3 = Aws::S3::Client.new(region: "us-east-1", stub_responses: true)
    root = MedusaStorage::Root::S3.new(name: "drive-test", bucket: "drive-test", region: "us-east-1")
    root.s3_client = s3
    expected_etag = MedusaStorage::EtagCalculator.new(GoogleDrive::Client::CHUNK_BYTES).tap do |digester|
      digester << "hello"
    end.etag
    s3.stub_responses(:head_object, [
      {status_code: 404, headers: {}, body: ""},
      {content_length: 5, metadata: {"google-drive-import-id" => import.id.to_s}, etag: expected_etag}
    ])
    s3.stub_responses(:upload_part, etag: "\"#{Digest::MD5.hexdigest("hello")}\"")
    allow(StorageManager.instance).to receive(:draft_root).and_return(root)
    job.perform
    expect(import.reload.status).to eq("complete")
    operations = s3.api_requests.map { |request| request[:operation_name] }
    expect(operations).to include(:create_multipart_upload, :upload_part, :complete_multipart_upload)
    expect(operations).not_to include(:put_object)
    expect(File.exist?(import.staging_path)).to be(false)
  end

  it "streams 8 MiB Drive ranges to S3 without staging the full file" do
    content = "x".b * (GoogleDrive::Client::CHUNK_BYTES + 10)
    metadata = drive_metadata(content)
    streaming_import = GoogleDriveImport.enqueue!(dataset: dataset, user: user, connection: connection,
                                                  metadata: metadata)
    allow(client).to receive(:metadata).and_return(metadata)
    allow(client).to receive(:chunk) do |_source, offset|
      content.byteslice(offset, GoogleDrive::Client::CHUNK_BYTES)
    end
    s3 = Aws::S3::Client.new(region: "us-east-1", stub_responses: true)
    root = MedusaStorage::Root::S3.new(name: "drive-test", bucket: "drive-test", region: "us-east-1")
    root.s3_client = s3
    expected_etag = MedusaStorage::EtagCalculator.new(GoogleDrive::Client::CHUNK_BYTES).tap do |digester|
      digester << content
    end.etag
    s3.stub_responses(:head_object, [
      {status_code: 404, headers: {}, body: ""},
      {content_length: content.bytesize, metadata: {"google-drive-import-id" => streaming_import.id.to_s},
       etag: expected_etag}
    ])
    s3.stub_responses(:upload_part, lambda do |context|
      {etag: "\"#{Digest::MD5.hexdigest(context.params[:body])}\""}
    end)
    allow(StorageManager.instance).to receive(:draft_root).and_return(root)

    described_class.new(streaming_import.id).perform

    parts = s3.api_requests.select { |request| request[:operation_name] == :upload_part }
    expect(parts.map { |part| part[:params][:body].bytesize }).to eq(
      [GoogleDrive::Client::CHUNK_BYTES, 10]
    )
    expect(streaming_import.reload.status).to eq("complete")
    expect(File.exist?(streaming_import.staging_path)).to be(false)
  end

  it "aborts the S3 multipart upload when the Drive checksum does not match" do
    s3 = Aws::S3::Client.new(region: "us-east-1", stub_responses: true)
    root = MedusaStorage::Root::S3.new(name: "drive-test", bucket: "drive-test", region: "us-east-1")
    root.s3_client = s3
    s3.stub_responses(:head_object, status_code: 404, headers: {}, body: "")
    s3.stub_responses(:upload_part, etag: "\"part-etag\"")
    s3.stub_responses(:abort_multipart_upload, {})
    allow(StorageManager.instance).to receive(:draft_root).and_return(root)
    allow(client).to receive(:chunk).and_return("wrong")

    job.perform

    expect(import.reload.status).to eq("failed")
    operations = s3.api_requests.map { |request| request[:operation_name] }
    expect(operations).to include(:abort_multipart_upload)
    expect(operations).not_to include(:complete_multipart_upload)
  end

  it "resumes uploaded S3 parts after a worker interruption" do
    content = "x".b * (GoogleDrive::Client::CHUNK_BYTES + 10)
    metadata = drive_metadata(content)
    resumable_import = GoogleDriveImport.enqueue!(dataset: dataset, user: user, connection: connection,
                                                  metadata: metadata)
    interrupted = false
    allow(client).to receive(:metadata).and_return(metadata)
    allow(client).to receive(:chunk) do |_source, offset|
      if offset == GoogleDrive::Client::CHUNK_BYTES && !interrupted
        interrupted = true
        raise GoogleDrive::RetryableError, "temporary"
      end
      content.byteslice(offset, GoogleDrive::Client::CHUNK_BYTES)
    end
    s3 = Aws::S3::Client.new(region: "us-east-1", stub_responses: true)
    root = MedusaStorage::Root::S3.new(name: "drive-test", bucket: "drive-test", region: "us-east-1")
    root.s3_client = s3
    complete = false
    expected_etag = MedusaStorage::EtagCalculator.new(GoogleDrive::Client::CHUNK_BYTES).tap do |digester|
      digester << content
    end.etag
    s3.stub_responses(:head_object, lambda do |_context|
      if complete
        {content_length: content.bytesize, metadata: {"google-drive-import-id" => resumable_import.id.to_s},
         etag: expected_etag}
      else
        {status_code: 404, headers: {}, body: ""}
      end
    end)
    s3.stub_responses(:upload_part, lambda do |context|
      {etag: "\"#{Digest::MD5.hexdigest(context.params[:body])}\""}
    end)
    s3.stub_responses(:complete_multipart_upload, lambda do |_context|
      complete = true
      {}
    end)
    allow(StorageManager.instance).to receive(:draft_root).and_return(root)

    expect { described_class.new(resumable_import.id).perform }.to raise_error(GoogleDrive::RetryableError)
    expect(resumable_import.reload.bytes_downloaded).to eq(GoogleDrive::Client::CHUNK_BYTES)
    described_class.new(resumable_import.id).error(nil, GoogleDrive::RetryableError.new("temporary"))
    described_class.new(resumable_import.id).perform

    upload_parts = s3.api_requests.select { |request| request[:operation_name] == :upload_part }
    expect(upload_parts.map { |part| part[:params][:part_number] }).to eq([1, 2])
    expect(resumable_import.reload.status).to eq("complete")
  end

  it "recognizes an S3 upload completed just before a worker interruption" do
    content = "hello"
    parts = [{"part_number" => 1, "etag" => "part-etag", "md5" => Digest::MD5.base64digest(content),
              "size" => content.bytesize}]
    import.update!(s3_upload_id: "completed-upload", s3_uploaded_parts: parts,
                   bytes_downloaded: content.bytesize)
    s3 = Aws::S3::Client.new(region: "us-east-1", stub_responses: true)
    root = MedusaStorage::Root::S3.new(name: "drive-test", bucket: "drive-test", region: "us-east-1")
    root.s3_client = s3
    expected_etag = MedusaStorage::EtagCalculator.new(GoogleDrive::Client::CHUNK_BYTES).tap do |digester|
      digester << content
    end.etag
    s3.stub_responses(:head_object, content_length: content.bytesize,
                                  metadata: {"google-drive-import-id" => import.id.to_s}, etag: expected_etag)
    allow(StorageManager.instance).to receive(:draft_root).and_return(root)

    job.perform

    expect(import.reload.status).to eq("complete")
    expect(import.s3_upload_id).to be_nil
    expect(s3.api_requests.map { |request| request[:operation_name] }).not_to include(
      :create_multipart_upload, :upload_part, :complete_multipart_upload
    )
  end

  it "aborts the S3 multipart upload when an import is cancelled" do
    import.update!(status: "cancelled", s3_upload_id: "incomplete-upload")
    s3 = Aws::S3::Client.new(region: "us-east-1", stub_responses: true)
    root = MedusaStorage::Root::S3.new(name: "drive-test", bucket: "drive-test", region: "us-east-1")
    root.s3_client = s3
    s3.stub_responses(:abort_multipart_upload, {})
    allow(StorageManager.instance).to receive(:draft_root).and_return(root)

    import.abort_s3_upload!

    expect(import.reload.s3_upload_id).to be_nil
    expect(s3.api_requests.map { |request| request[:operation_name] }).to include(:abort_multipart_upload)
  end

  it "does not leave a stored object if cancellation happens while copying" do
    storage_key = import.datafile.storage_key
    allow(draft_root).to receive(:copy_io_to).and_wrap_original do |method, *args|
      method.call(*args)
      import.update!(status: "cancelled")
      import.cleanup_incomplete!
    end
    job.perform
    expect(import.reload.status).to eq("cancelled")
    expect(draft_root.exist?(storage_key)).to be(false)
  end

  it "resumes a saved partial range after a worker interruption" do
    FileUtils.mkdir_p(File.dirname(import.staging_path))
    File.binwrite(import.staging_path, "he")
    import.update!(bytes_downloaded: 2)
    expect(client).not_to receive(:chunk).with(drive_metadata, 0)
    expect(client).to receive(:chunk).with(drive_metadata, 2).and_return("llo")
    job.perform
    expect(import.reload.status).to eq("complete")
  end

  it "restarts safely when a retry moves to a worker without its staging file" do
    import.update!(bytes_downloaded: 2)
    expect(client).to receive(:chunk).with(drive_metadata, 0).and_return("hello")
    job.perform
    expect(import.reload.status).to eq("complete")
  end

  it "rejects a source changed after confirmation" do
    allow(client).to receive(:metadata).and_return(drive_metadata.merge("version" => "2"))
    job.perform
    expect(import.reload.status).to eq("failed")
    expect(import.error_message).to include("changed")
    expect(import.datafile).to be_nil
    expect(connection.reload.encrypted_credentials).to be_nil
  end

  it "does not store a file with a checksum mismatch" do
    allow(client).to receive(:chunk).and_return("wrong")
    expect(draft_root).not_to receive(:copy_io_to)
    job.perform
    expect(import.reload.status).to eq("failed")
    expect(import.error_message).to include("checksum")
  end

  it "keeps resumable work and credentials on transient failures" do
    allow(client).to receive(:chunk).and_raise(GoogleDrive::RetryableError, "temporary")
    expect { job.perform }.to raise_error(GoogleDrive::RetryableError)
    job.error(nil, GoogleDrive::RetryableError.new)
    expect(import.reload.status).to eq("queued")
    expect(connection.reload.encrypted_credentials).to be_present
  end

  it "fails clearly without retrying when the staging directory is not writable" do
    allow(FileUtils).to receive(:mkdir_p).and_raise(Errno::EACCES, "dir_s_mkdir - /media/efs")
    expect { job.perform }.not_to raise_error
    expect(import.reload.status).to eq("failed")
    expect(import.error_message).to include("staging directory")
    expect(import.datafile).to be_nil
    expect(connection.reload.encrypted_credentials).to be_nil
  end

  it "uses a configured staging directory" do
    stub_const("IDB_CONFIG", IDB_CONFIG.merge(google: {staging_dir: File.join(@storage_directory, "drive")}))
    expect(import.staging_path).to eq(File.join(@storage_directory, "drive", "#{import.id}.part"))
  end

  it "waits without failing when there is not enough staging space" do
    allow(job).to receive(:free_bytes).and_return(1)
    expect(client).not_to receive(:chunk)
    expect { job.perform }.to change { Delayed::Job.where(queue: "google_drive").count }.by(1)
    expect(import.reload.status).to eq("queued")
    expect(import.error_message).to include("disk space")
    expect(Delayed::Job.find(import.datafile.job_id).run_at).to be > 5.minutes.from_now
  end

  it "runs only one import at a time across workers" do
    other = PG.connect(ActiveRecord::Base.connection.raw_connection.conninfo_hash.compact.reject { |_, v| v == "" })
    other.exec("SELECT pg_advisory_lock(#{described_class::SLOT_LOCK_KEY})")
    expect(client).not_to receive(:chunk)
    job.perform
    expect(import.reload.status).to eq("queued")
    expect(import.error_message).to include("another cloud import")
  ensure
    other&.close
  end

  it "cleans up after retries are exhausted" do
    job.failure(nil)
    expect(import.reload.status).to eq("failed")
    expect(import.datafile).to be_nil
    expect(connection.reload.encrypted_credentials).to be_nil
  end

  it "rechecks dataset state before downloading" do
    import
    dataset.update!(publication_state: Databank::PublicationState::RELEASED)
    expect(client).not_to receive(:chunk)
    job.perform
    expect(import.reload.status).to eq("failed")
  end

  it "cancels the import when its placeholder datafile is removed" do
    import.datafile.destroy!
    expect(import.reload.status).to eq("cancelled")
    expect(connection.reload.encrypted_credentials).to be_nil
    expect(client).not_to receive(:chunk)
    job.perform
  end

  it "does not treat a missing delayed job as proof that an import is complete" do
    import.datafile.job.destroy!
    expect(import.datafile.upload_complete?).to be(false)
  end
end
