# frozen_string_literal: true

require "signet/oauth_2/client"

module GoogleDriveHelpers
  def self.included(group)
    group.before do
      allow(Sunspot).to receive(:index)
      allow(Sunspot).to receive(:index!)
      allow(Sunspot).to receive(:remove_all!)
    end
  end

  def drive_metadata(content = "hello")
    {"id" => "drive-file-123", "name" => "sample.csv", "size" => content.bytesize.to_s,
     "mimeType" => "text/csv", "version" => "1", "md5Checksum" => Digest::MD5.hexdigest(content),
     "capabilities" => {"canDownload" => true}}
  end

  def create_drive_connection(user:, dataset:)
    connection = GoogleDriveConnection.create!(user: user, dataset: dataset, expires_at: 24.hours.from_now)
    client = Signet::OAuth2::Client.new(access_token: "test-access-token", refresh_token: "test-refresh-token",
                                      expires_at: 1.hour.from_now)
    connection.store_tokens!(client)
    connection
  end
end
