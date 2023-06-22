# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  def self.seeding?
    @@seeding
  end

  ##
  # @param user [User]
  # (local, non-shibboleth) identity provider is assumed
  #
  def log_in_as(user)
    post "/auth/identity/callback", params: {
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
  end

  def teardown_s3
    s3_client = Application.aws_client
    response = s3_client.list_objects({bucket: bucket_name, max_keys: 1000})
    s3_client.delete_objects(bucket: bucket_name, delete: response.contents) if response.contents.count.positive?
  end

end