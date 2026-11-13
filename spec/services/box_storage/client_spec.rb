# frozen_string_literal: true

require "rails_helper"

RSpec.describe BoxStorage::Client do
  include BoxHelpers
  let(:connection) { instance_double(BoxConnection, access_token: "box-access") }
  let(:client) { described_class.new(connection) }
  let(:http) { instance_double(Net::HTTP) }

  before do
    allow(Net::HTTP).to receive(:start).and_yield(http)
  end

  it "accepts the 50 GB boundary but rejects larger, empty, unavailable and non-file items" do
    expect(described_class.validate_metadata!(box_metadata.merge("size" => "50000000000"))["size"]).to eq("50000000000")
    [{"size" => "50000000001"}, {"size" => "0"}, {"type" => "folder"}, {"canDownload" => false},
     {"name" => "../file"}, {"name" => "note.boxnote"}, {"sha1" => nil}, {"version" => nil}].each do |change|
      expect { described_class.validate_metadata!(box_metadata.merge(change)) }.to raise_error(BoxStorage::Error)
    end
  end

  it "downscopes browser tokens to picker-only access" do
    expect(described_class).to receive(:token_request).with(
      grant_type: "urn:ietf:params:oauth:grant-type:token-exchange", subject_token: "box-access",
      subject_token_type: "urn:ietf:params:oauth:token-type:access_token", scope: "base_picker"
    ).and_return("access_token" => "picker-token")
    expect(client.picker_token).to eq("picker-token")
  end

  it "normalizes Box metadata while preserving the version and download permission" do
    raw = {
      id: "12345", type: "file", name: "test.csv", size: 5, sha1: "a" * 40,
      file_version: {id: "6789"}, permissions: {can_download: true},
      is_download_available: true, item_status: "active"
    }
    response = instance_double(Net::HTTPOK, code: "200", body: raw.to_json)
    expect(http).to receive(:request) do |request, &block|
      expect(request.uri.path).to eq("/2.0/files/12345")
      expect(request["Authorization"]).to eq("Bearer box-access")
      block.call(response)
    end
    result = described_class.validate_metadata!(client.metadata("12345"))
    expect(result).to include("id" => "12345", "size" => "5", "sha1" => "a" * 40,
                              "version" => "6789", "canDownload" => true)
  end

  it "accepts a PDF when Box omits optional permission and availability fields" do
    raw = {
      id: "12345", type: "file", name: "test.pdf", size: 5, sha1: "a" * 40,
      file_version: {id: "6789"}, item_status: "active"
    }
    response = instance_double(Net::HTTPOK, code: "200", body: raw.to_json)
    allow(http).to receive(:request).and_yield(response)
    result = described_class.validate_metadata!(client.metadata("12345"))
    expect(result).to include("name" => "test.pdf", "mimeType" => "application/pdf", "canDownload" => nil)
  end

  it "distinguishes explicit download denials, unavailable content, and inactive files" do
    [
      [{"canDownload" => false}, /Check file permissions and the app's read\/write scope, then authorize Box again/],
      [{"available" => false}, /content is not available for download/],
      [{"item_status" => "trashed"}, /not active in Box/]
    ].each do |change, message|
      expect { described_class.validate_metadata!(box_metadata.merge(change)) }
        .to raise_error(BoxStorage::Error, message)
    end
  end

  it "logs rejection flags without including filenames or credentials" do
    metadata = box_metadata.merge("canDownload" => false, "access_token" => "private-token")
    expect(Rails.logger).to receive(:warn).with(
      'Box import metadata rejected: {"type":"file","canDownload":false,"available":true,"item_status":"active"}'
    )
    expect { described_class.validate_metadata!(metadata) }.to raise_error(BoxStorage::Error)
  end

  it "still enforces Box authorization when optional download permission is missing" do
    response = instance_double(Net::HTTPForbidden, code: "403")
    allow(http).to receive(:request).and_yield(response)
    expect { client.chunk(box_metadata.merge("canDownload" => nil), 0) }
      .to raise_error(BoxStorage::Error, /denied access.*HTTP 403/)
  end

  it "follows Box download redirects without forwarding the OAuth bearer token" do
    redirect = instance_double(Net::HTTPFound, code: "302")
    allow(redirect).to receive(:[]).with("Location").and_return("https://dl.boxcloud.com/d/file/download")
    binary = "\xB5\xFF\x00\x10\x80".b
    response = instance_double(Net::HTTPPartialContent, code: "206")
    allow(response).to receive(:[]).with("Content-Range").and_return("bytes 0-4/5")
    allow(response).to receive(:read_body).and_yield(binary)
    expect(http).to receive(:request).twice do |request, &block|
      if request.uri.host == "api.box.com"
        expect(request.uri.query).to eq("version=6789")
        expect(request["Authorization"]).to eq("Bearer box-access")
        block.call(redirect)
      else
        expect(request.uri.host).to eq("dl.boxcloud.com")
        expect(request["Authorization"]).to be_nil
        expect(request["Range"]).to eq("bytes=0-4")
        block.call(response)
      end
    end
    expect(client.chunk(box_metadata, 0)).to eq(binary)
  end

  it "rejects download redirects outside Box and never requests their targets" do
    response = instance_double(Net::HTTPFound, code: "302")
    allow(response).to receive(:[]).with("Location").and_return("https://example.com/download")
    expect(http).to receive(:request).once.and_yield(response)
    expect { client.chunk(box_metadata, 0) }.to raise_error(BoxStorage::Error, /unexpected download location/)
  end

  it "rejects incorrect ranges and oversized responses" do
    response = instance_double(Net::HTTPPartialContent, code: "206")
    allow(response).to receive(:[]).with("Content-Range").and_return("bytes 0-4/5")
    allow(response).to receive(:read_body).and_yield("too many bytes")
    allow(http).to receive(:request).and_yield(response)
    expect { client.chunk(box_metadata, 0) }.to raise_error(BoxStorage::Error, /more data/)
  end

  it "treats file preparation, throttling and server errors as retryable" do
    ["202", "429", "503"].each do |code|
      response = instance_double(Net::HTTPResponse, code: code)
      allow(http).to receive(:request).and_yield(response)
      expect { client.chunk(box_metadata, 0) }.to raise_error(BoxStorage::RetryableError)
    end
  end
end
