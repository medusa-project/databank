# frozen_string_literal: true

##
# StorageManager
# ---------------
# Singleton class that manages storage locations for the application.
#
# The StorageManager is a singleton class that manages the storage locations
# used by the application. It provides access to the root directories for
# draft storage, Medusa storage, message storage, and temporary file storage.
# It also provides access to the root directories for Globus download and ingest
# storage, but only in certain server environments.
#
# The StorageManager is initialized with the root directories for draft, Medusa,
# and message storage, as well as the temporary directory used for temporary
# file storage. It also initializes an S3 resource object for use in interacting
# with S3 storage.
#
# The StorageManager provides methods for ensuring that local buckets exist,
# emptying local buckets, setting up a bucket, checking whether a bucket exists,
# and deleting objects from a bucket. It also provides a method for returning
# the client options for use in creating the S3 client.
#
# The StorageManager is a singleton class, so there is only one instance of it
# in the application.
#
# == Attributes
# * +draft_root+ - the root directory for draft storage
# * +medusa_root+ - the root directory for Medusa storage
# * +message_root+ - the root directory for message storage
# * +tmpfs_root+ - the root directory for temporary file storage
# * +globus_download_root+ - the root directory for Globus download storage
# * +globus_ingest_root+ - the root directory for Globus ingest storage
# * +root_set+ - the root set object that contains the root directories
# * +tmpdir+ - the temporary directory used for temporary file storage
# * +resource+ - the S3 resource object used for interacting with S3 storage
#
# # frozen_string_literal: true
#
# ##
# # StorageManager
# # ---------------
# # Singleton class that manages storage locations for the application.
# #
# # The StorageManager is a singleton class that manages the storage locations
# # used by the application. It provides access to the root directories for
# # draft storage, Medusa storage, message storage, and temporary file storage.
# # It also provides access to the root directories for Globus download and ingest
# # storage, but only in certain server environments.
# #
# # The StorageManager is initialized with the root directories for draft, Medusa,
# # and message storage, as well as the temporary directory used for temporary
# # file storage. It also initializes an S3 resource object for use in interacting
# # with S3 storage.
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
                :resource

  ##
  # initialize
  # Initializes the object
  def initialize
    storage_config = STORAGE_CONFIG[:storage].map(&:to_h)
    self.root_set = MedusaStorage::RootSet.new(storage_config)
    self.draft_root = root_set.at("draft")
    self.report_root = root_set.at("reports")
    self.medusa_root = root_set.at("medusa")
    self.message_root = root_set.at("message")
    self.tmpfs_root = root_set.at("tmpfs")
    self.globus_download_root = root_set.at("globus_download")
    self.globus_ingest_root = root_set.at("globus_ingest")
    self.resource = Aws::S3::Resource.new(client_options)
    initialize_tmpdir
  end

  ##
  # initialize_tmpdir
  # Initializes the temporary directory
  def initialize_tmpdir
    self.tmpdir = IDB_CONFIG[:storage_tmpdir]
  end

  ############################################################
  # methods to support local development and testing
  ##########################################################
  ##
  # ensure_local_buckets
  # Ensures that local buckets exist
  def ensure_local_buckets
    return false unless Rails.env.development? || Rails.env.test?

    s3_client = Application.aws_client
    local_bucket_names = STORAGE_CONFIG[:local_buckets]
    local_bucket_names.each do |bucket_name|
      next if bucket_exists?(s3_client: s3_client, bucket_name: bucket_name)

      setup_bucket(bucket_name: bucket_name)

      if bucket_exists?(s3_client: s3_client, bucket_name: bucket_name)
        puts "Local bucket #{bucket_name} created."
      else
        puts "Local bucket #{bucket_name} not created."
      end
    end
  end

  ##
  # empty_local_buckets
  # Empties local buckets
  def empty_local_buckets
    return false unless Rails.env.development? || Rails.env.test?

    s3_client = Application.aws_client
    local_bucket_names = STORAGE_CONFIG[:local_buckets]
    local_bucket_names.each do |bucket_name|
      next unless bucket_exists?(s3_client: s3_client, bucket_name: bucket_name)

      delete_objects(bucket: bucket_name)
    end
  end

  ##
  # setup_bucket
  # Sets up a bucket
  # @param bucket_name [String] The name of the bucket.
  def setup_bucket(bucket_name:)
    return false unless Rails.env.development? || Rails.env.test?

    s3_client = Application.aws_client
    s3_client.create_bucket(bucket: bucket_name) unless bucket_exists?(s3_client: s3_client, bucket_name: bucket_name)
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
    delete_objects(bucket: bucket_name)
  end

  ##
  # bucket_exists?
  # Checks to see whether an Amazon Simple Storage Service
  # (Amazon S3) bucket exists.
  #
  # @param s3_client [Aws::S3::Client] An initialized S3 client.
  # @param bucket_name [String] The name of the bucket.
  # @return [Boolean] true if the bucket exists; otherwise, false.
  def bucket_exists?(s3_client:, bucket_name:)
    response = s3_client.list_buckets
    response.buckets.each do |bucket|
      return true if bucket.name == bucket_name
    end
    false
  rescue StandardError => e
    Rails.logger.warn "Error listing buckets: #{e.message}"
    false
  end

  ##
  # delete_objects
  # Deletes objects from a bucket
  # @param bucket [String] The name of the bucket.
  # @param key_prefix [String] The prefix of the keys to delete.
  def delete_objects(bucket:, key_prefix: "")
    bucket = resource.bucket(bucket)
    bucket.objects(prefix: key_prefix).each(&:delete)
  end

  ##
  # client_options
  # Returns the client options for use in creating the S3 client.
  # @return [Hash] the client options
  def client_options
    opts = {region: IDB_CONFIG[:aws][:region]}
    if Rails.env.development? || Rails.env.test?
      # In development and test, we connect to a custom endpoint, and
      # credentials are drawn from the application configuration.
      opts[:endpoint]         = STORAGE_CONFIG[:storage][0][:endpoint]
      opts[:force_path_style] = true
      key = STORAGE_CONFIG[:storage][0][:aws_access_key_id]
      secret = STORAGE_CONFIG[:storage][0][:aws_secret_access_key]
      opts[:credentials] = Aws::Credentials.new(key, secret)
    end
    opts
  end

end