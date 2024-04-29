# frozen_string_literal: true

##
# Datafile::Viewable
# ------------------
# This module is included in the Datafile model to provide methods for handling the preview of the datafile
# in the UI. It sets the datafile's preview type and text, based on the datafile's mime type.
# It also provides methods for determining the preview type of the datafile.
# The methods in this module are used in the datafile controller and views.
# This module is included in the Datafile model.

module Datafile::Viewable
  extend ActiveSupport::Concern
  ALLOWED_CHAR_NUM = 1024 * 8
  ALLOWED_DISPLAY_BYTES = ALLOWED_CHAR_NUM * 8

  class_methods do
    ##
    # Return the datafiles peek type based on its mime type and size
    # @param [String] mime_type the datafile's mime type
    # @param [Integer] num_bytes the number of bytes in the binary object
    # @return [String] the datafile's peek type
    def peek_type_from_mime(mime_type, num_bytes)
      return Databank::PeekType::NONE unless num_bytes && mime_type && !mime_type.empty?

      mime_parts = mime_type.split("/")
      return Databank::PeekType::NONE unless mime_parts.length == 2

      return Databank::PeekType::MARKDOWN if mime_parts[0] == "markdown"

      text_subtypes = ["csv", "xml", "x-sh", "x-javascript", "json", "r", "rb"]
      supported_image_subtypes = ["jp2", "jpeg", "dicom", "gif", "png", "bmp"]
      listing_subtypes = ["x-zip-compressed",
                          "zip",
                          "x-7z-compressed",
                          "x-rar-compressed",
                          "x-tar",
                          "x-xz",
                          "x-gzip",
                          "gzip",
                          "x-rar",
                          "x-gtar"]
      pdf_subtypes = ["pdf", "x-pdf"]
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
      elsif listing_subtypes.include?(subtype)
        Databank::PeekType::LISTING
      else
        Databank::PeekType::NONE
      end
    end

    ##
    # @param [Integer] peek_bytes the number of bytes to read from the datafile for the preview
    # @return [String] the datafile's text preview based on the number of bytes allowed
    # @note: this method reads the first peek_bytes from the datafile and returns the text
    # It encodes the text as UTF-8, replaces invalid characters with "?", and deletes null characters
    def peek_string(peek_bytes:)
      peek_bytes.read.encode("UTF-8", invalid: :replace, replace: "?").delete("\u0000")
    end
  end

  ############################################################
  # instance methods:
  # #########################################################

  ##
  # Sets the datafile's preview type and text, based on the datafile's mime type
  # @return [Boolean] true if the preview was successfully set
  # @note: side effect: sets the datafile's peek_type and peek_text attributes
  # Logs but does not raise exceptions, because the preview is not critical to the datafile's functionality
  def handle_peek
    markdown_extensions = ["md", "MD", "mdown", "mkdn", "mkd", "markdown"]
    Rails.logger.warn "no binary_name for datafile id: #{id}" unless binary_name
    return false unless binary_name

    file_parts = binary_name.split(".")
    if file_parts && markdown_extensions.include?(file_parts.last)
      markdown_text = Application.markdown.render(all_text_peek)
      self.peek_type = Databank::PeekType::MARKDOWN
      self.peek_text = markdown_text
      return self.save
    end

    initial_peek_type = Datafile.peek_type_from_mime(mime_type, binary_size)
    return true unless initial_peek_type

    case initial_peek_type
    when Databank::PeekType::ALL_TEXT
      self.peek_type = initial_peek_type
      self.peek_text = all_text_peek
      self.save
    when Databank::PeekType::PART_TEXT
      self.peek_type = initial_peek_type
      self.peek_text = part_text_peek
      self.save
    when Databank::PeekType::LISTING
      initiate_processing_task
    else
      self.peek_type = initial_peek_type
      self.save
    end
  rescue StandardError => error
    Rails.logger.warn "unexpected Standard Error in handling peek for datafile id: #{id} in dataset: #{dataset.key}."
    Rails.logger.warn error.class
    Rails.logger.warn error.message
    self.update_attribute("peek_type", Databank::PeekType::NONE)
    self.update_attribute("peek_text", "")
    false
  end

  ##
  # mime_type_from_name
  # This method returns the mime type of the datafile based on its name
  # @return [String] the mime type of the datafile
  # Logs but does not raise exceptions, because the mime type is not critical to the datafile's functionality
  def mime_type_from_name
    return nil unless binary_name

    file_parts = binary_name.split(".")
    return nil unless file_parts

    extension = file_parts.last
    mime_type = MIME::Types.type_for(extension).first&.content_type
    mime_type
  rescue StandardError => error
    Rails.logger.warn "unexpected problem deriving mime type for datafile id: #{id} in dataset: #{dataset.key}."
    Rails.logger.warn error.class
    Rails.logger.warn error.message
    "application/octet-stream"
  end

  ##
  # @return [String] the datafile's preview text, used when the whole text would be too large
  def part_text_peek
    return "file not found" unless current_root.exist?(storage_key)

    if IDB_CONFIG[:aws][:s3_mode]
      first_bytes = current_root.get_bytes(storage_key, 0, ALLOWED_DISPLAY_BYTES)
      return Datafile.peek_string(peek_bytes: first_bytes)
    end

    File.open(filepath) do |file|
      return  file.read(ALLOWED_DISPLAY_BYTES)
    end
  end

  ##
  # @return [String] the datafile's full text to use as a preview
  def all_text_peek
    return "file not found" unless current_root.exist?(storage_key)

    if IDB_CONFIG[:aws][:s3_mode]
      all_bytes = current_root.get_bytes(storage_key, 0, binary_size)
      return Datafile.peek_string(peek_bytes: all_bytes)
    end

    File.open(filepath) do |file|
      return  file.read
    end
  end

  ##
  # Path for iiif server to use in UI previews on landing page
  # medusa mounts are different on iiif server
  # @return [String] the path to the datafile on the iiif server
  def iiif_bytestream_path
    case storage_root
    when "draft"
      File.join(IDB_CONFIG[:iiif][:draft_base], storage_key)
    when "medusa"
      File.join(IDB_CONFIG[:iiif][:medusa_base], storage_key)
    else
      raise StandardError.new("invalid storage_root found for datafile: #{self.web_id}")
    end
  end

  ##
  # @return [String] the datafile's file extension
  def file_extension
    return "" unless bytestream_name

    filename_split = bytestream_name.split(".")
    return "" unless filename_split.count > 1

    filename_split.last
  end

  ##
  # @return [Boolean] true if the datafile is a markdown file
  def markdown?
    peek_type == Databank::PeekType::MARKDOWN
  end

  ##
  # @return [Boolean] true if the datafile is an archive file
  def archive?
    peek_type == Databank::PeekType::LISTING
  end

  ##
  # @return [Boolean] true if the datafile is a text file small enough to all fit in the preview
  def all_txt?
    peek_type == Databank::PeekType::ALL_TEXT
  end

  ##
  # @return [Boolean] true if the datafile is a text file too large to all fit in the preview
  def part_txt?
    peek_type == Databank::PeekType::PART_TEXT
  end

  ##
  # @return [Boolean] true if the datafile is an image file
  def image?
    supported_extensions = %w[avi bmp jp2 jpg jpeg png tif tiff]
    (peek_type == Databank::PeekType::IMAGE) &&
        file_extension &&
        supported_extensions.include?(file_extension)
  end

  ##
  # @return [Boolean] true if the datafile is a microsoft file that can be previewed in the browser
  def microsoft?
    peek_type == Databank::PeekType::MICROSOFT
  end

  ##
  # @return [Boolean] true if the datafile is a pdf file that can be previewed in the browser
  def pdf?
    peek_type == Databank::PeekType::PDF
  end

  ##
  # @return [String] the url for the microsoft preview of the datafile
  def microsoft_preview_url
    preview_base = "https://view.officeapps.live.com/op/view.aspx?src"
    preview_ref = "https%3A%2F%2Fdatabank.illinois.edu%2Fdatafiles%2F#{web_id}%2Fview"
    "#{preview_base}=#{preview_ref}" if microsoft?
  end
end
