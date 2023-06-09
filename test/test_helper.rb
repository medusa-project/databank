# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
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