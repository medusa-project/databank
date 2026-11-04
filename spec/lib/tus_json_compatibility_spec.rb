require "spec_helper"
require "active_support"
require "active_support/json"
require "active_support/core_ext/object/json"
require "rack/mock"
require "tus/server"
require "tus/storage/s3"

RSpec.describe "Tus JSON compatibility" do
  it "round-trips upload metadata through Rails JSON" do
    metadata = { "Upload-Length" => "12", "Upload-Offset" => "0" }

    expect(ActiveSupport::JSON.decode(ActiveSupport::JSON.encode(metadata))).to eq(metadata)
  end

  it "creates an S3 upload and persists its metadata" do
    storage = Tus::Storage::S3.new(
      bucket: "uploads-test",
      region: "us-east-1",
      stub_responses: true
    )
    server = Class.new(Tus::Server)
    server.opts[:storage] = storage

    response = Rack::MockRequest.new(server).post(
      "/",
      "HTTP_TUS_RESUMABLE" => "1.0.0",
      "HTTP_UPLOAD_LENGTH" => "12"
    )

    expect(response.status).to eq(201), response.body
    expect(response["Location"]).not_to be_nil

    request = storage.client.api_requests.find { |entry| entry[:operation_name] == :put_object }
    expect(request).not_to be_nil
    metadata = JSON.parse(request[:params][:body])
    expect(metadata).to include("Upload-Length" => "12", "Upload-Offset" => "0")
    expect(metadata.fetch("multipart_id")).not_to be_empty
  end
end
