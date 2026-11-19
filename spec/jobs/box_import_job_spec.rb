# frozen_string_literal: true

require "rails_helper"

RSpec.describe BoxImportJob do
  include BoxHelpers
  let(:user) { create(:user, :admin) }
  let(:dataset) { create(:dataset) }
  let(:connection) { create_box_connection(user: user, dataset: dataset) }
  let(:content) { "\xB5\xFF\x00\x10\x80".b }
  let(:metadata) { box_metadata(content) }
  let(:import) { BoxImport.enqueue!(dataset: dataset, user: user, connection: connection, metadata: metadata) }
  let(:client) { instance_double(BoxStorage::Client, metadata: metadata) }
  let(:job) { described_class.new(import.id) }

  before do
    @root, @s3 = stub_box_s3
    allow(BoxStorage::Client).to receive(:new).and_return(client)
    allow(client).to receive(:chunk).with(metadata, 0, CloudImports::CHUNK_BYTES).and_return(content)
    @s3.stub_responses(:head_object, status_code: 404, headers: {}, body: "")
    @s3.stub_responses(:upload_part, etag: "\"part-etag\"")
    @s3.stub_responses(:abort_multipart_upload, {})
  end

  it "streams binary content to prefixed S3 keys and verifies SHA-1 without filesystem staging" do
    expected_etag = MedusaStorage::EtagCalculator.new(BoxStorage::Client::CHUNK_BYTES).tap do |digest|
      digest << content
    end.etag
    @s3.stub_responses(:head_object, [
      {status_code: 404, headers: {}, body: ""},
      {content_length: content.bytesize, metadata: {"box-import-id" => import.id.to_s}, etag: expected_etag}
    ])
    expect(File).not_to receive(:open)
    job.perform
    expect(import.reload.status).to eq("complete")
    expect(import.datafile.upload_status).to eq("uploaded")
    expect(connection.reload.encrypted_credentials).to be_nil
    part = @s3.api_requests.find {|request| request[:operation_name] == :upload_part }
    expect(part[:params]).to include(key: "draft/#{import.datafile.storage_key}", body: content)
  end

  it "aborts on checksum mismatch and removes the placeholder" do
    allow(client).to receive(:chunk).and_return("wrong")
    job.perform
    expect(import.reload.status).to eq("failed")
    expect(import.error_message).to include("checksum")
    expect(import.datafile).to be_nil
    expect(@s3.api_requests.map {|request| request[:operation_name] }).to include(:abort_multipart_upload)
  end

  it "keeps uploaded parts on transient failures and removes them when retries are exhausted" do
    allow(client).to receive(:chunk).and_raise(BoxStorage::RetryableError, "temporary")
    expect { job.perform }.to raise_error(BoxStorage::RetryableError)
    expect(import.reload.s3_upload_id).to be_present
    job.error(nil, BoxStorage::RetryableError.new)
    expect(import.reload.status).to eq("queued")
    job.failure(nil)
    expect(import.reload.status).to eq("failed")
    expect(import.s3_upload_id).to be_nil
  end

  it "waits for the shared Drive/Box transfer slot without using a failure attempt" do
    import
    allow(CloudImports::TransferSlot).to receive(:synchronize).and_return(false)
    expect(client).not_to receive(:chunk)
    expect { job.perform }.to change { Delayed::Job.where(queue: "box").count }.by(1)
    expect(import.reload.status).to eq("queued")
    expect(import.error_message).to include("another cloud import")
    expect(import.datafile.job.run_at).to be > 30.seconds.from_now
  end

  it "resumes S3 parts and rechecks the full Box checksum after interruption" do
    part = "\xB5".b * BoxStorage::Client::CHUNK_BYTES
    full_content = part + "tail".b
    large_metadata = box_metadata(full_content)
    large_import = BoxImport.enqueue!(dataset: dataset, user: user, connection: connection, metadata: large_metadata)
    allow(client).to receive(:metadata).and_return(large_metadata)
    interrupted = false
    allow(client).to receive(:chunk) do |_source, offset, part_bytes|
      if offset.positive? && !interrupted
        interrupted = true
        raise BoxStorage::RetryableError, "temporary"
      end
      full_content.byteslice(offset, part_bytes)
    end
    large_job = described_class.new(large_import.id)
    expect { large_job.perform }.to raise_error(BoxStorage::RetryableError)
    expect(large_import.reload.bytes_downloaded).to eq(part.bytesize)
    allow(CloudImports).to receive(:part_bytes).and_return(16 * 1024 * 1024)
    expected_etag = MedusaStorage::EtagCalculator.new(BoxStorage::Client::CHUNK_BYTES).tap do |digest|
      digest << full_content
    end.etag
    @s3.stub_responses(:head_object, [
      {status_code: 404, headers: {}, body: ""},
      {content_length: full_content.bytesize, metadata: {"box-import-id" => large_import.id.to_s}, etag: expected_etag}
    ])
    large_job.perform
    expect(large_import.reload.status).to eq("complete")
    parts = @s3.api_requests.select {|request| request[:operation_name] == :upload_part }
    expect(parts.map {|request| request[:params][:part_number] }).to eq([1, 2])
  end

  it "does not upload or complete an unexpectedly short range" do
    allow(client).to receive(:chunk).and_return("hi")
    expect { job.perform }.to raise_error(CloudImports::RetryableError, /incomplete file range/)
    operations = @s3.api_requests.map {|request| request[:operation_name] }
    expect(operations).not_to include(:upload_part, :complete_multipart_upload)
    expect(import.reload.status).to eq("importing")
  end

  it "uses a dynamically sized part for upload and resumes it after interruption" do
    part_bytes = 16 * 1024 * 1024
    content = "x".b * part_bytes + "tail".b
    metadata = box_metadata(content)
    dynamic_import = BoxImport.enqueue!(dataset: dataset, user: user, connection: connection, metadata: metadata)
    allow(CloudImports).to receive(:part_bytes).and_return(part_bytes)
    allow(client).to receive(:metadata).and_return(metadata)
    interrupted = false
    allow(client).to receive(:chunk) do |_source, offset, size|
      expect(size).to eq(part_bytes)
      if offset.positive? && !interrupted
        interrupted = true
        raise BoxStorage::RetryableError, "temporary"
      end
      content.byteslice(offset, size)
    end
    dynamic_job = described_class.new(dynamic_import.id)
    expect { dynamic_job.perform }.to raise_error(BoxStorage::RetryableError)
    expect(dynamic_import.reload.s3_uploaded_parts.first["size"]).to eq(part_bytes)
    expected_etag = MedusaStorage::EtagCalculator.new(part_bytes).tap {|digest| digest << content }.etag
    @s3.stub_responses(:head_object, [
      {status_code: 404, headers: {}, body: ""},
      {content_length: content.bytesize, metadata: {"box-import-id" => dynamic_import.id.to_s}, etag: expected_etag}
    ])
    dynamic_job.perform
    expect(dynamic_import.reload.status).to eq("complete")
    parts = @s3.api_requests.select {|request| request[:operation_name] == :upload_part }
    expect(parts.map {|request| request[:params][:body].bytesize }).to eq([part_bytes, 4])
  end

  it "fails and aborts an old upload whose part size would exceed the S3 part limit" do
    metadata = box_metadata.merge("size" => "150000000000")
    large_import = BoxImport.enqueue!(dataset: dataset, user: user, connection: connection, metadata: metadata)
    large_import.update!(s3_upload_id: "old-upload", s3_uploaded_parts: [
      {"part_number" => 1, "size" => CloudImports::CHUNK_BYTES, "md5" => "saved", "etag" => "saved"}
    ])
    allow(client).to receive(:metadata).and_return(metadata)
    expect(client).not_to receive(:chunk)
    described_class.new(large_import.id).perform
    expect(large_import.reload.status).to eq("failed")
    expect(large_import.error_message).to include("Start a new import")
    expect(@s3.api_requests.map {|request| request[:operation_name] }).to include(:abort_multipart_upload)
  end

  it "rejects changed source versions and cancels when a placeholder is removed" do
    allow(client).to receive(:metadata).and_return(metadata.merge("version" => "new-version"))
    job.perform
    expect(import.reload.status).to eq("failed")
    expect(import.error_message).to include("changed in Box")
  end

  it "cancels and aborts when its placeholder datafile is removed" do
    import.update!(s3_upload_id: "cancel-upload")
    import.datafile.destroy!
    expect(import.reload.status).to eq("cancelled")
    expect(import.s3_upload_id).to be_nil
    expect(connection.reload.encrypted_credentials).to be_nil
  end

  it "does not restart an import cancelled during its initial metadata request" do
    allow(client).to receive(:metadata) do
      import.update!(status: "cancelled", error_message: "The import was cancelled.")
      import.cleanup_incomplete!
      metadata
    end
    expect(client).not_to receive(:chunk)
    job.perform
    expect(import.reload.status).to eq("cancelled")
    expect(import.datafile).to be_nil
  end
end
