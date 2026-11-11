require "spec_helper"
require "stringio"
require "medusa_storage"
require_relative "../../config/initializers/medusa_storage_s3"

RSpec.describe MedusaStorage::S3::ReadIO do
  let(:contents) { "storage compatibility" }
  let(:root) { double("storage root") }
  let(:reader) { described_class.new(root, "example.txt") }

  before do
    allow(root).to receive(:size).with("example.txt").and_return(contents.bytesize)
    allow(root).to receive(:get_bytes) do |key, start, length|
      expect(key).to eq("example.txt")
      StringIO.new(contents.byteslice(start, length))
    end
  end

  it "reads S3 content through the io-like API" do
    expect(reader.read(7)).to eq("storage")
    expect(reader.read).to eq(" compatibility")
    expect(reader.read(1)).to be_nil
  end

  it "supports seeking and rewinding" do
    reader.seek(8)
    expect(reader.read(13)).to eq("compatibility")

    reader.rewind
    expect(reader.read).to eq(contents)
  end
end

RSpec.describe "MedusaStorage binary multipart uploads" do
  let(:part_size) { MedusaStorage::Root::S3::AMAZON_PART_SIZE }
  let(:contents) { (0..255).to_a.pack("C*") * (part_size / 256 + 1) }
  let(:client) { Aws::S3::Client.new(region: "us-east-1", stub_responses: true) }
  let(:root) do
    MedusaStorage::Root::S3.new(
      name: "globus", bucket: "globus-test", region: "us-east-1", prefix: "downloads/",
      aws_access_key_id: "test-access-key", aws_secret_access_key: "test-secret-key"
    )
  end
  let(:expected_etag) do
    parts = [contents.byteslice(0, part_size), contents.byteslice(part_size..)]
    %("#{Digest::MD5.hexdigest(parts.map { |part| Digest::MD5.digest(part) }.join)}-2")
  end
  let(:uploaded_parts) { Queue.new }

  around do |example|
    original_encoding = Encoding.default_internal
    Encoding.default_internal = Encoding::UTF_8
    example.run
  ensure
    Encoding.default_internal = original_encoding
  end

  before do
    root.s3_client = client
    client.stub_responses(:head_object, etag: expected_etag)
    client.stub_responses(:upload_part, lambda do |context|
      uploaded_parts << [context.params[:part_number], context.params[:body].read]
      { etag: "part-#{context.params[:part_number]}" }
    end)
  end

  it "uploads binary bytes unchanged across multipart boundaries without deprecation warnings" do
    expect do
      root.copy_io_to("archive.bin", StringIO.new(contents), "source-md5", nil, mtime: Time.at(123).utc)
    end.not_to output.to_stderr

    parts = uploaded_parts.size.times.map { uploaded_parts.pop }.sort_by(&:first).map(&:last)
    expect(parts.map(&:bytesize)).to eq([part_size, 256])
    expect(parts.join.b).to eq(contents)
    request = client.api_requests.find { |entry| entry[:operation_name] == :create_multipart_upload }
    expect(request[:params]).to include(
      bucket: "globus-test", key: "downloads/archive.bin",
      metadata: { "md5chksum" => "source-md5", "mtime" => "123.0" }
    )
    expect(Encoding.default_internal).to eq(Encoding::UTF_8)
  end

  it "uses binary multipart uploads for known sizes at the large-object threshold" do
    root.copy_io_to("archive.bin", StringIO.new(contents), nil, MedusaStorage::Root::S3::AMAZON_CUTOFF_SIZE)

    expect(uploaded_parts.size).to eq(2)
    expect(client.api_requests.map { |entry| entry[:operation_name] }).to include(:complete_multipart_upload)
  end

  it "leaves small-object uploads on the existing single-request path" do
    root.copy_io_to("archive.bin", StringIO.new(contents), nil, contents.bytesize)

    expect(client.api_requests.map { |entry| entry[:operation_name] }).to eq([:put_object])
  end

  context "when copying an existing version file" do
    let(:source_root) do
      MedusaStorage::Root::S3.new(
        name: "preserved", bucket: "preserved-test", region: "us-east-1",
        aws_access_key_id: "test-access-key", aws_secret_access_key: "test-secret-key"
      )
    end

    before do
      allow(source_root).to receive(:mtime).with("old/archive.bin").and_return(Time.at(123).utc)
      allow(source_root).to receive(:md5_sum).with("old/archive.bin").and_return("source-md5")
      allow(source_root).to receive(:size).with("old/archive.bin").and_return(contents.bytesize)
    end

    it "keeps compatible S3 copies on the gem's server-side copy path" do
      source_root.copy_targets.add(root.name)
      source_object = source_root.s3_object("old/archive.bin")
      allow(source_root).to receive(:s3_object).with("old/archive.bin").and_return(source_object)
      expect(source_object).to receive(:copy_to).with(
        have_attributes(bucket_name: "globus-test", key: "downloads/new/archive.bin"),
        multipart_copy: false, metadata: { mtime: "123.0", "md5chksum" => "source-md5" },
        metadata_directive: "REPLACE"
      )
      expect(root).not_to receive(:copy_io_to_large)

      root.copy_content_to("new/archive.bin", source_root, "old/archive.bin")
    end

    it "keeps compatible files larger than 5 GiB on the server-side multipart copy path" do
      source_root.copy_targets.add(root.name)
      allow(source_root).to receive(:size).with("old/archive.bin").and_return(
        MedusaStorage::Root::S3::AMAZON_CUTOFF_SIZE + 1
      )
      source_object = source_root.s3_object("old/archive.bin")
      allow(source_root).to receive(:s3_object).with("old/archive.bin").and_return(source_object)
      expect(source_object).to receive(:copy_to).with(
        have_attributes(bucket_name: "globus-test", key: "downloads/new/archive.bin"),
        multipart_copy: true, metadata: { mtime: "123.0", "md5chksum" => "source-md5" },
        metadata_directive: "REPLACE"
      )
      expect(root).not_to receive(:copy_io_to_large)

      root.copy_content_to("new/archive.bin", source_root, "old/archive.bin")
    end

    it "copies binary content through the branch's ReadIO when server-side copies are unavailable" do
      stub_const("MedusaStorage::Root::S3::INPUT_IO_THRESHOLD", 1)
      stub_const("MedusaStorage::Root::S3::AMAZON_CUTOFF_SIZE", part_size)
      expect(MedusaStorage::S3::ReadIO).to receive(:new).with(source_root, "old/archive.bin").and_call_original
      allow(source_root).to receive(:get_bytes) do |key, start, length|
        expect(key).to eq("old/archive.bin")
        StringIO.new(contents.byteslice(start, length))
      end

      root.copy_content_to("new/archive.bin", source_root, "old/archive.bin")

      parts = uploaded_parts.size.times.map { uploaded_parts.pop }.sort_by(&:first).map(&:last)
      expect(parts.join.b).to eq(contents)
      request = client.api_requests.find { |entry| entry[:operation_name] == :create_multipart_upload }
      expect(request[:params]).to include(
        key: "downloads/new/archive.bin", metadata: { "md5chksum" => "source-md5", "mtime" => "123.0" }
      )
    end
  end

  it "propagates upload failures and aborts the multipart upload" do
    client.stub_responses(:upload_part, "AccessDenied")

    expect do
      root.copy_io_to("archive.bin", StringIO.new(contents), nil, nil)
    end.to raise_error(Aws::S3::MultipartUploadError)

    operations = client.api_requests.map { |entry| entry[:operation_name] }
    expect(operations).to include(:abort_multipart_upload)
    expect(operations).not_to include(:complete_multipart_upload)
  end

  it "keeps existing objects when the uploaded ETag does not match" do
    client.stub_responses(:head_object, etag: '"incorrect"')

    expect do
      root.copy_io_to("archive.bin", StringIO.new(contents), nil, nil)
    end.to raise_error(MedusaStorage::Error::MD5)

    expect(client.api_requests.map { |entry| entry[:operation_name] }).not_to include(:delete_object)
  end

  it "removes newly created objects when the uploaded ETag does not match" do
    client.stub_responses(:head_object, [
      { status_code: 404, headers: {}, body: "" },
      { etag: '"incorrect"' },
      { etag: '"incorrect"' }
    ])

    expect do
      root.copy_io_to("archive.bin", StringIO.new(contents), nil, nil)
    end.to raise_error(MedusaStorage::Error::MD5)

    expect(client.api_requests.map { |entry| entry[:operation_name] }).to include(:delete_object)
  end
end
