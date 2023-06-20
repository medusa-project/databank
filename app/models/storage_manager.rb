# frozen_string_literal: true

require "singleton"

class StorageManager
  include Singleton
  attr_accessor :draft_root,
                :medusa_root,
                :message_root,
                :tmpfs_root,
                :globus_download_root,
                :globus_ingest_root,
                :root_set,
                :tmpdir,
                :local_buckets_created

  def initialize
    storage_config = STORAGE_CONFIG[:storage].map(&:to_h)
    self.root_set = MedusaStorage::RootSet.new(storage_config)
    self.draft_root = root_set.at("draft")
    self.medusa_root = root_set.at("medusa")
    self.message_root = root_set.at("message")
    self.tmpfs_root = root_set.at("tmpfs")
    if Rails.env.production? || Rails.env.demo?
      self.globus_download_root = root_set.at("globus_download")
      self.globus_ingest_root = root_set.at("globus_ingest")
    end
    self.local_buckets_created = false
    initialize_tmpdir
  end

  def initialize_tmpdir
    self.tmpdir = IDB_CONFIG[:storage_tmpdir]
  end

  # methods to support local development and testing
  def ensure_local_buckets
    return false unless Rails.env.development? || Rails.env.test?

    local_bucket_names = ["databank-local-main", "medusa-local-main"]
    local_bucket_names.each do |bucket_name|
      next if bucket_exists?(bucket_name: bucket_name)

      setup_bucket(bucket_name: bucket_name)
    end
    self.local_buckets_created = true
  end

  def setup_bucket(bucket_name:)
    s3_client = Application.aws_client
    s3_client.create_bucket(bucket: bucket_name)
    s3_client.put_bucket_policy(bucket: bucket_name,
                                policy: JSON.generate({
                                                        Version:   "2012-10-17",
                                                        Statement: [
                                                          {
                                                            Principal: "*",
                                                            Effect:    "Allow",
                                                            Action: [
                                                              "s3:PutObject",
                                                              "s3:GetObject",
                                                              "s3:GetObjectVersion",
                                                              "s3:DeleteObject",
                                                              "s3:DeleteObjectVersion"
                                                            ],
                                                            Resource:  [
                                                              "arn:aws:s3:::#{bucket_name}/*"
                                                            ]
                                                          }
                                                        ]
                                                      }))
    response = s3_client.list_objects({bucket: bucket_name, max_keys: 1000})
    s3_client.delete_objects(bucket: bucket_name, delete: response.contents) if response.contents.count.positive?
  end

  def bucket_exists?(bucket_name:)
    s3_client = Application.aws_client
    response = s3_client.list_buckets
    response.buckets.each do |bucket|
      return true if bucket.name == bucket_name
    end
    false
  rescue StandardError => e
    Rails.logger.warn "Error listing buckets: #{e.message}"
    false
  end

end
