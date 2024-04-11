# frozen_string_literal: true

##
# Datafile model
# Represents a file in a dataset
# Methods not concerned with computed attributes are included in the Datafile modules.

require "zip"
require "seven_zip_ruby"
require "filemagic"
require "mime/types"
require "minitar"
require "zlib"
require "rest-client"

class Datafile < ApplicationRecord
  include ActiveModel::Serialization
  include Datafile::AsyncUploadable
  include Datafile::Downloadable
  include Datafile::Extractable
  include Datafile::Storable
  include Datafile::Versionable
  include Datafile::Viewable
  belongs_to :dataset
  has_many :nested_items, dependent: :destroy

  WEB_ID_LENGTH = 5

  ALLOWED_CHAR_NUM = 1024 * 8
  ALLOWED_DISPLAY_BYTES = ALLOWED_CHAR_NUM * 8
  before_create { self.web_id ||= generate_web_id }
  after_create :handle_peek
  after_create :set_dataset_nested_updated_at
  after_update :set_dataset_nested_updated_at
  before_destroy :set_dataset_nested_updated_at
  before_destroy :destroy_job
  before_destroy :remove_binary

  ##
  # Returns the datafile web_id as the parameter for the datafile
  #
  # @return [String] the datafile web_id
  def to_param
    self.web_id
  end

  ##
  # Returns a JSON representation of the datafile
  # @param [Hash] _options the options to pass to the JSON generator
  # @return [Hash] the JSON representation of the datafile
  def as_json(_options={})
    super(only: %i[web_id binary_name binary_size medusa_id storage_root storage_key created_at updated_at])
  end

  ##
  # Sets the nested_updated_at attribute of this datafile's dataset to the current time
  def set_dataset_nested_updated_at
    dataset.update_attribute(:nested_updated_at, Time.now.utc)
  end

  ##
  # @return [String] the datafile's name
  def bytestream_name
    binary_name
  end

  ##
  # @return [Integer] the datafile's size in bytes
  def bytestream_size
    if binary_size
      binary_size
    elsif current_root&.exist?(storage_key)
      self.binary_size = current_root.size(storage_key)
      save
      binary_size
    else
      Rails.logger.warn("binary not found for datafile: #{self.web_id} root: #{storage_root}, key: #{storage_key}")
      0
    end
  end

  ##
  # @return [AWS::S3::Object] the datafile's S3 object, if it exists
  def s3_object
    return nil unless exists_on_storage?

    current_root.s3_object(storage_key)
  end

  ##
  # @return [String] the datafile's S3 object's etag, nil if it doesn't exist
  def etag
    s3_object&.etag
  end

  ##
  # @return [String] the datafile's name
  def name
    binary_name
  end

  ##
  # @return [Boolean] whether the datafile is a readme file
  def readme?
    return false if binary_name.nil?

    binary_name.downcase.include?("readme")
  end

  ##
  # Generates a guaranteed-unique web ID, of which there are
  # 36^WEB_ID_LENGTH available.
  #
  def generate_web_id
    proposed_id = nil
    loop do
      proposed_id = (36**(WEB_ID_LENGTH - 1) +
          rand(36**WEB_ID_LENGTH - 36**(WEB_ID_LENGTH - 1))).to_s(36)
      break unless Datafile.find_by(web_id: proposed_id)
    end
    proposed_id
  end
end
