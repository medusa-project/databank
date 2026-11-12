# frozen_string_literal: true

require "rails_helper"

RSpec.describe GoogleDrive::Client do
  include GoogleDriveHelpers

  let(:connection) { instance_double(GoogleDriveConnection, access_token: "test-token") }
  let(:client) { described_class.new(connection) }
  let(:http) { instance_double(Net::HTTP) }

  before do
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(client).to receive(:sleep)
  end

  describe ".validate_metadata!" do
    it "accepts ordinary files and the exact 10 GB boundary" do
      expect(described_class.validate_metadata!(drive_metadata)).to eq(drive_metadata)
      expect { described_class.validate_metadata!(drive_metadata.merge("size" => "10000000000")) }.not_to raise_error
    end

    it "rejects empty files, missing sizes and one byte over the limit" do
      ["0", nil, "10000000001", "-1", "invalid"].each do |size|
        expect { described_class.validate_metadata!(drive_metadata.merge("size" => size)) }.to raise_error(GoogleDrive::Error)
      end
    end

    it "rejects native documents, folders, shortcuts and Shared Drives" do
      %w[document spreadsheet presentation folder shortcut].each do |type|
        expect {
          described_class.validate_metadata!(drive_metadata.merge("mimeType" => "application/vnd.google-apps.#{type}"))
        }.to raise_error(GoogleDrive::Error)
      end
      expect {
        described_class.validate_metadata!(drive_metadata.merge("driveId" => "shared-drive"))
      }.to raise_error(GoogleDrive::Error)
    end

    it "honors download restrictions and trash state" do
      expect {
        described_class.validate_metadata!(drive_metadata.merge("capabilities" => {"canDownload" => false}))
      }.to raise_error(GoogleDrive::Error, /cannot be downloaded/)
      expect {
        described_class.validate_metadata!(drive_metadata.merge("trashed" => true))
      }.to raise_error(GoogleDrive::Error)
    end

    it "rejects unsafe filenames" do
      ["../file.csv", "dir\\file.csv", "file\n.csv", "..", ""].each do |name|
        expect {
          described_class.validate_metadata!(drive_metadata.merge("name" => name))
        }.to raise_error(GoogleDrive::Error, /Rename/)
      end
    end
  end

  describe "#metadata" do
    it "uses a fixed Google API origin and bearer authorization" do
      response = instance_double(Net::HTTPOK, code: "200", body: drive_metadata.to_json, read_body: nil)
      expect(http).to receive(:request) do |request, &block|
        expect(request.uri.host).to eq("www.googleapis.com")
        expect(request["Authorization"]).to eq("Bearer test-token")
        expect(request.uri.query).to include("capabilities")
        block.call(response)
      end
      expect(client.metadata("drive-file-123")).to eq(drive_metadata)
    end

    it "rejects arbitrary URLs and path injection without making a request" do
      expect(http).not_to receive(:request)
      expect { client.metadata("https://example.test/secret") }.to raise_error(GoogleDrive::Error)
      expect { client.metadata("../secret") }.to raise_error(GoogleDrive::Error)
    end

    it "refreshes an expired access token and retries" do
      expired = instance_double(Net::HTTPUnauthorized, code: "401")
      success = instance_double(Net::HTTPOK, code: "200", body: drive_metadata.to_json, read_body: nil)
      expect(http).to receive(:request).ordered.and_yield(expired)
      expect(http).to receive(:request).ordered.and_yield(success)
      expect(connection).to receive(:access_token).with(force_refresh: true)
      expect(client.metadata("drive-file-123")).to eq(drive_metadata)
    end

    it "bounds retries for quota errors" do
      response = instance_double(Net::HTTPForbidden, code: "403",
                                 body: {error: {errors: [{reason: "userRateLimitExceeded"}]}}.to_json)
      expect(http).to receive(:request).exactly(3).times.and_yield(response)
      expect { client.metadata("drive-file-123") }.to raise_error(GoogleDrive::RetryableError)
    end

    it "does not retry forbidden downloads or expose response bodies" do
      response = instance_double(Net::HTTPForbidden, code: "403", body: '{"error":{"message":"private detail"}}')
      expect(http).to receive(:request).once.and_yield(response)
      expect { client.metadata("drive-file-123") }.to raise_error(GoogleDrive::Error, /HTTP 403/)
    end
  end

  describe "#chunk" do
    it "requests and verifies an exact byte range" do
      response = instance_double(Net::HTTPPartialContent, code: "206")
      allow(response).to receive(:[]).with("Content-Range").and_return("bytes 2-4/5")
      allow(response).to receive(:read_body).and_yield("llo")
      expect(http).to receive(:request) do |request, &block|
        expect(request["Range"]).to eq("bytes=2-4")
        expect(request.uri.query).to eq("alt=media")
        block.call(response)
      end
      expect(client.chunk(drive_metadata, 2)).to eq("llo")
    end

    it "rejects a server ignoring Range rather than buffering the full file" do
      response = instance_double(Net::HTTPOK, code: "200")
      expect(response).not_to receive(:read_body)
      allow(http).to receive(:request).and_yield(response)
      expect { client.chunk(drive_metadata, 0) }.to raise_error(GoogleDrive::Error, /range/)
    end

    it "bounds memory even if Google returns too much content" do
      response = instance_double(Net::HTTPPartialContent, code: "206")
      allow(response).to receive(:[]).with("Content-Range").and_return("bytes 0-4/5")
      allow(response).to receive(:read_body).and_yield("too much data")
      allow(http).to receive(:request).and_yield(response)
      expect { client.chunk(drive_metadata, 0) }.to raise_error(GoogleDrive::Error, /more data/)
    end
  end
end
