# frozen_string_literal: true

require "zip"
require "seven_zip_ruby"
require "filemagic"
require "mime/types"
require "minitar"
require "zlib"
require "rest-client"
require "whatlanguage"

class Datafile < ApplicationRecord
  include ActiveModel::Serialization
  include Datafile::Viewable
  belongs_to :dataset
  has_many :nested_items, dependent: :destroy

  WEB_ID_LENGTH = 5

  ALLOWED_CHAR_NUM = 1024 * 8
  ALLOWED_DISPLAY_BYTES = ALLOWED_CHAR_NUM * 8
  before_create { self.web_id ||= generate_web_id }
  after_create :handle_peek

  before_destroy :destroy_job
  before_destroy :remove_binary

  def to_param
    self.web_id
  end

  def as_json(_options={})
    super(only: %i[web_id binary_name binary_size medusa_id storage_root storage_key created_at updated_at])
  end

  def extractor_task
    return nil unless task_id

    ExtractorTask.find_by(id: task_id)
  end

  def handle_peek
    markdown_extensions = ["md", "MD", "mdown", "mkdn", "mkd", "markdown"]
    raise StandardError.new("no binary_name for datafile id: #{self.id}") unless self.binary_name

    file_parts = self.binary_name.split(".")
    if file_parts && markdown_extensions.include?(file_parts.last)
      self.peek_type = Databank::PeekType::MARKDOWN
      self.peek_text = Application.markdown.render(all_text_peek)
      save!
      return true
    end

    initial_peek_type = Datafile.peek_type_from_mime(mime_type, binary_size)
    return true unless initial_peek_type

    case initial_peek_type
    when Databank::PeekType::ALL_TEXT
      self.peek_type = initial_peek_type
      self.peek_text = all_text_peek
    when Databank::PeekType::PART_TEXT
      self.peek_type = initial_peek_type
      self.peek_text = part_text_peek
    when Databank::PeekType::LISTING
      self.initiate_processing_task
    else
      return true
    end
    save!
  rescue StandardError => error
    Rails.logger.warn "problem in handling peek for datafile id: #{self.id}"
    Rails.logger.warn error.message
    # TEMPORARY DEBUG
    Rails.logger.warn error.backtrace.join "\n"
  end

  def file_download_tallies
    FileDownloadTally.where(file_web_id: self.web_id)
  end

  def total_downloads
    FileDownloadTally.where(file_web_id: self.web_id).sum :tally
  end

  def bytestream_name
    binary_name
  end

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

  def current_root
    StorageManager.instance.root_set.at(storage_root)
  end

  def storage_root_bucket
    current_root.bucket if IDB_CONFIG[:aws][:s3_mode]
  end

  def storage_key_with_prefix
    if IDB_CONFIG[:aws][:s3_mode]
      "#{current_root.prefix}#{storage_key}"
    else
      storage_key
    end
  end

  def storage_root_path
    if IDB_CONFIG[:aws][:s3_mode]
      nil
    else
      current_root&.real_path
    end
  end

  # within the context of the databank server mounts
  def filepath
    base = storage_root_path
    if base
      File.join(base, storage_key)
    else
      raise StandardError.new("no filesystem path found for datafile: #{self.web_id}")
    end
  end

  # Set this up so that we use local storage for small files, for some definition of small
  # might want to extract this elsewhere so that is generally available and easy to make
  # robust for whatever application.
  def tmpdir_for_with_input_file
    expected_size = binary_size || current_root.size(storage_key)
    if expected_size > 500.megabytes
      StorageManager.instance.tmpdir
    else
      Dir.tmpdir
    end
  end

  # wrap the storage root's ability to yield an io on the content
  def with_input_io
    current_root.with_input_io(storage_key) do |io|
      yield io
    end
  end

  # wrap the storage root's ability to yield a file path having the appropriate content in it
  def with_input_file
    current_root.with_input_file(storage_key, tmp_dir: tmpdir_for_with_input_file) do |file|
      yield file
    end
  end

  def exists_on_storage?
    current_root.exist?(key)
  end

  def remove_from_storage
    current_root.delete_content(key)
  end

  def name
    binary_name
  end

  # medusa mounts are different on iiif server
  def iiif_bytestream_path
    if storage_root == "draft"
      File.join(IDB_CONFIG[:iiif][:draft_base], storage_key)
    elsif storage_root == "medusa"
      File.join(IDB_CONFIG[:iiif][:medusa_base], storage_key)
    else
      raise StandardError.new("invalid storage_root found for datafile: #{self.web_id}")
    end
  end

  def file_extension
    return "" unless bytestream_name

    filename_split = bytestream_name.split(".")
    return "" unless filename_split.count > 1

    filename_split.last
  end

  def ip_downloaded_file_today(request_ip)
    DayFileDownload.where(["ip_address = ? and file_web_id = ? and download_date = ?",
                           request_ip,
                           self.web_id,
                           Date.current]).count > 0
  end

  delegate :key, to: :dataset, prefix: true

  def target_key
    "#{dataset.dirname}/dataset_files/#{binary_name}"
  end

  # has side-effect of updating record if the bytestream is in medusa, but the record did not indicate
  # if bytestream is found the same in draft and medusa roots, the draft bytestream is deleted
  def in_medusa
    return false unless dataset
    return false unless dataset.identifier && dataset.identifier != ""

    in_medusa = false # start out with the assumption that it is not in medusa, then check and handle

    # datafile_target_key = "#{dataset.dirname}/dataset_files/#{self.binary_name}"

    if StorageManager.instance.medusa_root.exist?(target_key)
      in_medusa = true

      if storage_root && storage_key && storage_root == "draft" && storage_key != ""

        # If the binary object also exists in draft system, delete duplicate.
        #  Can't do full equivalence check (S3 etag is not always MD5), so check sizes.
        if StorageManager.instance.draft_root.exist?(storage_key)
          draft_size = StorageManager.instance.draft_root.size(storage_key)
          medusa_size = StorageManager.instance.medusa_root.size(target_key)

          if draft_size == medusa_size
            # If the ingest into Medusa was successful,
            # delete redundant binary object
            # and update Illinois Data Bank datafile record
            StorageManager.instance.draft_root.delete_content(storage_key)
            in_medusa = true
          else
            in_medusa = false
            exception_string("Different size draft vs medusa. Dataset: #{dataset.key}, Datafile: #{datafile.web_id}")
            notification = DatabankMailer.error(exception_string)
            notification.deliver_now
          end
        else
          in_medusa = true
        end
      else
        in_medusa = true
      end

      if in_medusa
        self.storage_root = "medusa"
        self.storage_key = target_key
        save
      end
    end
    in_medusa
  end

  def bytestream?
    storage_root &&
        storage_root != "" &&
        storage_key &&
        storage_key != "" &&
        current_root.exist?(storage_key)
  end

  def record_download(request_ip)
    return nil if Robot.exists?(address: request_ip)

    return nil if dataset.publication_state == Databank::PublicationState::DRAFT

    return nil if Date.current < dataset.release_date

    unless dataset.ip_downloaded_dataset_today(request_ip)

      day_ds_download_set = DatasetDownloadTally.where(["dataset_key= ? and download_date = ?",
                                                        dataset.key,
                                                        Date.current])

      if day_ds_download_set.count == 1

        today_dataset_download = day_ds_download_set.first
        today_dataset_download.tally = today_dataset_download.tally + 1
        today_dataset_download.save
      elsif day_ds_download_set.count.zero?
        DatasetDownloadTally.create(tally:         1,
                                    download_date: Date.current,
                                    dataset_key:   dataset.key,
                                    doi:           dataset.identifier)
      else
        Rails.logger.warn "wrong # dataset tally download of #{self.web_id} on #{Date.current} ip: #{request_ip}"
      end

    end

    return nil if ip_downloaded_file_today(request_ip)

    DayFileDownload.create(ip_address:    request_ip,
                           download_date: Date.current,
                           file_web_id:   self.web_id,
                           filename:      bytestream_name,
                           dataset_key:   dataset.key,
                           doi:           dataset.identifier)

    day_df_download_set = FileDownloadTally.where(["file_web_id = ? and download_date = ?",
                                                   self.web_id,
                                                   Date.current])

    if day_df_download_set.count == 1
      today_file_download = day_df_download_set.first
      today_file_download.tally = today_file_download.tally + 1
      today_file_download.save
    elsif day_df_download_set.count.zero?
      FileDownloadTally.create(tally:         1,
                               download_date: Date.current,
                               dataset_key:   dataset.key,
                               doi:           dataset.identifier,
                               file_web_id:   web_id,
                               filename:      bytestream_name)
    else
      Rails.logger.warn "wrong # of file tally download of #{web_id} on #{Date.current} ip: #{request_ip}"
    end
  end

  def remove_binary
    return nil unless storage_key

    if StorageManager.instance.draft_root.exist?(storage_key)
      StorageManager.instance.draft_root.delete_content(storage_key)
    end

    return nil unless StorageManager.instance.draft_root.exist?("#{storage_key}.info")

    StorageManager.instance.draft_root.delete_content("#{storage_key}.info")
  end

  def job
    Delayed::Job.find_by(id: job_id) if job_id
  end

  def job_status
    if job
      if job.locked_by
        :processing
      else
        :pending
      end
    else
      :complete
    end
  end

  def destroy_job
    job&.destroy
  end

  def download_link
    case cfs_file.storage_root.root_type
    when :filesystem
      download_cfs_file_path(cfs_file)
    when :s3
      cfs_file.storage_root.presigned_get_url(cfs_file.key,
                                              response_content_disposition: disposition("attachment", cfs_file),
                                              response_content_type:        safe_content_type(cfs_file))
    else
      raise "Unrecognized storage root type #{cfs_file.storage_root.type}"
    end
  end

  def self.peek_type_from_mime(mime_type, num_bytes)
    return Databank::PeekType::NONE unless num_bytes && mime_type && !mime_type.empty?

    mime_parts = mime_type.split("/")
    return Databank::PeekType::NONE unless mime_parts.length == 2

    return Databank::PeekType::MARKDOWN if mime_parts[0] == "markdown"

    text_subtypes = %w[csv xml x-sh x-javascript json r rb]
    supported_image_subtypes = %w[jp2 jpeg dicom gif png bmp]
    zip_archive_subtypes = %w[x-zip-compressed zip]
    nonzip_archive_subtypes = %w[x-7z-compressed x-tar]
    pdf_subtypes = %w[pdf x-pdf]
    microsoft_subtypes = ["msword",
                          "vnd.openxmlformats-officedocument.wordprocessingml.document",
                          "vnd.openxmlformats-officedocument.wordprocessingml.template",
                          "vnd.ms-word.document.macroEnabled.12",
                          "vnd.ms-word.template.macroEnabled.12",
                          "vnd.ms-excel",
                          "vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                          "vnd.openxmlformats-officedocument.spreadsheetml.template",
                          "vnd.ms-excel.sheet.macroEnabled.12",
                          "vnd.ms-excel.template.macroEnabled.12",
                          "vnd.ms-excel.addin.macroEnabled.12",
                          "vnd.ms-excel.sheet.binary.macroEnabled.12",
                          "vnd.ms-powerpoint",
                          "vnd.openxmlformats-officedocument.presentationml.presentation",
                          "vnd.openxmlformats-officedocument.presentationml.template",
                          "vnd.openxmlformats-officedocument.presentationml.slideshow",
                          "vnd.ms-powerpoint.addin.macroEnabled.12",
                          "vnd.ms-powerpoint.presentation.macroEnabled.12",
                          "vnd.ms-powerpoint.template.macroEnabled.12",
                          "vnd.ms-powerpoint.slideshow.macroEnabled.12"]
    subtype = mime_parts[1].downcase
    if mime_parts[0] == "text" || text_subtypes.include?(subtype)

      return Databank::PeekType::ALL_TEXT unless num_bytes > ALLOWED_DISPLAY_BYTES

      Databank::PeekType::PART_TEXT
    elsif mime_parts[0] == "image"
      return Databank::PeekType::NONE unless supported_image_subtypes.include?(subtype)

      Databank::PeekType::IMAGE
    elsif microsoft_subtypes.include?(subtype)
      Databank::PeekType::MICROSOFT
    elsif pdf_subtypes.include?(subtype)
      Databank::PeekType::PDF
    elsif zip_archive_subtypes.include?(subtype)
      Databank::PeekType::LISTING
    elsif nonzip_archive_subtypes.include?(subtype)
      Databank::PeekType::LISTING
    else
      Databank::PeekType::NONE
    end
  end

  def part_text_peek
    return "file not found" unless current_root.exist?(storage_key)

    if IDB_CONFIG[:aws][:s3_mode]
      first_bytes = current_root.get_bytes(storage_key, 0, ALLOWED_DISPLAY_BYTES)
      return Datafile.scrubbed_peek_string(peek_bytes: first_bytes)
    end

    File.open(filepath) do |file|
      return  file.read(ALLOWED_DISPLAY_BYTES)
    end
  end

  def all_text_peek
    return "file not found" unless current_root.exist?(storage_key)

    if IDB_CONFIG[:aws][:s3_mode]
      all_bytes = current.get_bytes(storage_key, 0, binary_size)
      return Datafile.scrubbed_peek_string(peek_bytes: all_bytes)
    end

    File.open(filepath) do |file|
      return  file.read
    end
  end

  def self.scrubbed_peek_string(peek_bytes:)
    # TODO scrub string
    peek_bytes.string
  end

  def initiate_processing_task
    return nil unless Rails.env.production? || Rails.env.demo?

    extractor_task = ExtractorTask.create(web_id: web_id)
    update_attribute(:task_id, extractor_task.id) if extractor_task
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
