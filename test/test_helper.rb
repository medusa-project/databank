# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase

  # Setup fixtures in test/fixtures/*.yml
  fixtures :invitees, :identities, "user/identities", :datasets, :datafiles, :creators, :related_materials

  def self.seeding?
    @@seeding
  end

  ##
  # @param user [User]
  # (local, non-shibboleth) identity.rb provider is assumed
  #
  def log_in_as(user)
    post "/auth/identity.rb/callback", params: {
      auth_key: user.email,
      password: "password"
    }
  end

  ##
  # Creates the application S3 bucket (if it does not already exist) and
  # uploads objects to it corresponding to every [datafile].
  #
  def setup_s3
    StorageManager.instance.ensure_local_buckets
    @@seeding = true
    Datafile.all.each do |datafile|
      File.open(file_fixture(datafile.binary_name), "r") do |file|
        StorageManager.instance.draft_root.put_object(key: datafile.storage_key, file: file)
      end
    end
    @@seeding = false
  end

  def teardown_s3
    s3_client = Application.aws_client
    response = s3_client.list_objects({bucket: bucket_name, max_keys: 1000})
    s3_client.delete_objects(bucket: bucket_name, delete: response.contents) if response.contents.count.positive?
  end
end