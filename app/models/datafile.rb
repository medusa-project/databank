# frozen_string_literal: true

##
# Represents a file in a dataset
#
# == Attributes
#
# * +description+ - description of the file
# * +binary+ - deprecated (was used to store the file using paperclip gem)
# * +web_id+ - web_id of the file, a unique identifier
# * +dataset_id+ - id of the dataset that the file belongs to
# * +job_id+ - id of the job used to upload the file, if any
# * +box_filename+ - filename of the file in Box, for use in import-from-Box feature
# * +box_filesize_display+ - size of the file in Box, for use in import-from-Box feature
# * +medusa_id+ - The id of the file in Medusa
# * +medusa_path+ - The path of the file in Medusa, if stored on a filesystem
# * +binary_name+ - The name of the file
# * +binary_size+ - The size of the file in bytes
# * +upload_file_size+ - The size of the file when uploaded, in bytes, reported by the client
# * +upload_status+ - The status of the upload, one of "pending", "uploading", "uploaded", "error"
# * +peek_type+ - The type of peek, one of "text", "image", "pdf", "audio", "video", "unknown" for preview
# * +peek_text+ - The text of the peek, for use in preview
# * +storage_root+ - The root of the storage location, for use with MedusaStorage gem
# * +storage_prefix+ - The prefix of the storage location, for use with MedusaStorage gem
# * +storage_key+ - The key of the storage location, for use with MedusaStorage gem
# * +mime_type+ - The mime type of the file
# * +task_id+ - The id of the task used to extract features from an archive type file, if any
# Methods not concerned with derived attributes are included in the Datafile modules.

require "zip"
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

  before_create { self.web_id ||= generate_web_id }
  after_create :set_dataset_nested_updated_at
  before_destroy :set_dataset_nested_updated_at
  before_destroy :destroy_job
  before_destroy :remove_binary

  validates :binary_name, presence: true

  ##
  # Returns the datafile web_id as the parameter for the datafile
  #
  # @return [String] the datafile web_id
  def to_param
    self.web_id
  end

  ##
  # Returns the URL for the datafile in the Illinois Data Bank
  #
  # @return [String] the URL for the datafile in the Illinois Data Bank
  def databank_url
    "#{IDB_CONFIG[:root_url_text]}/datafiles/#{self.to_param}"
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
  # ensure_mime_type
  # This method ensures that the mime type is set
  # It sets the mime type to the mime type from the name if the mime type is not set
  def ensure_mime_type
    self.update_attribute(:mime_type, self.mime_type_from_name) unless mime_type
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
