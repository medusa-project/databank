# frozen_string_literal: true

module BoxHelpers
  def self.included(group)
    group.include GoogleDriveHelpers
  end

  def box_metadata(content = "hello")
    {"id" => "12345", "name" => "sample.csv", "size" => content.bytesize.to_s,
     "mimeType" => "text/csv", "version" => "6789", "sha1" => Digest::SHA1.hexdigest(content),
     "type" => "file", "canDownload" => true, "available" => true, "item_status" => "active"}
  end

  def box_tokens
    {"access_token" => "box-access", "refresh_token" => "box-refresh", "expires_in" => 3600}
  end

  def create_box_connection(user:, dataset:)
    BoxConnection.create!(user: user, dataset: dataset, expires_at: 24.hours.from_now).tap do |connection|
      connection.store_tokens!(box_tokens)
    end
  end

  def stub_box_s3
    s3 = Aws::S3::Client.new(region: "us-east-1", stub_responses: true)
    root = MedusaStorage::Root::S3.new(name: "box-test", bucket: "box-test", region: "us-east-1", prefix: "draft/")
    root.s3_client = s3
    allow(StorageManager.instance).to receive(:draft_root).and_return(root)
    [root, s3]
  end
end
