# frozen_string_literal: true

module Datafile::Viewable
  extend ActiveSupport::Concern

  def preview
    if is_txt?

      filestring = File.read(bytestream_path)

      if filestring
        chardet = CharDet.detect(filestring)
        if chardet
          detected_encoding = chardet["encoding"]

          # Rails.logger.warn "\n***\n#{detected_encoding}\n***\n"

          if detected_encoding == "UTF-8"
            filestring
          else
            filestring.encode("utf-8", detected_encoding, invalid: :replace, undef: :replace, replace: "")
          end
        else
          "no text detected in file"
        end
      else
        "no content detected"
      end

    elsif archive?
      archive_listview(bytestream_name.split(".").last)

    else
      "no text preview available"
    end
  end

  def archive_listview(extension)
    case extension

    when "zip"
      entry_list_text = `unzip -l "#{bytestream_path}"`
      filepaths_arr = []

      entry_list_array = entry_list_text.split("\n")

      # first three lines are headers, last two lines are summary
      entry_list_array.each_with_index do |raw_entry, index|
        next unless index > 2 && index < (entry_list_array.length - 2)

        entry_array = raw_entry.strip.split " "
        if entry_array[-1]
          filepaths_arr.push(entry_array[-1]) unless entry_array[-1].include?(".DS_Store")

        end
      end

      filepaths_arr_to_html(filepaths_arr)

    when "7z"

      entry_list_text = `7za l "#{bytestream_path}"`

      filepaths_arr = []

      entry_list_array = entry_list_text.split("\n")

      # first twenty lines are headers, last two lines are summary
      entry_list_array.each_with_index do |raw_entry, index|
        next unless index > 19 && index < (entry_list_array.length - 2)

        entry_array = raw_entry.strip.split " "
        filepaths_arr.push(entry_array[-1]) if entry_array[-1] && entry_array[-1] != ".DS_Store"
      end

      filepaths_arr_to_html(filepaths_arr)

    when "gz"

      inside_extension = ""
      filename_arr = bytestream_name.split(".")
      inside_extension = filename_arr[-2] if filename_arr.length > 1

      case inside_extension

      when "tar"

        entry_list_text = `tar -tf "#{bytestream_path}"`

        filepaths_arr_to_html(entry_list_text.split("\n"))

      else
        filepaths_arr_to_html([bytestream_name.chomp(".gz")])
      end

      # return 'listing of gz files not yet implemented'

    when "tar"
      entry_list_text = `tar -tf "#{bytestream_path}"`
      filepaths_arr_to_html(entry_list_text.split("\n"))

    else
      "no listing available for this format"

    end
  end

  def filepaths_arr_to_html(filepaths_arr)
    return_string = '<span class="glyphicon glyphicon-folder-open"></span> '

    return_string << bytestream_name

    filepaths_arr.each do |filepath|
      next unless filepath.exclude?("__MACOSX/") && filepath.exclude?(".DS_Store")

      name_arr = filepath.split("/")

      name_arr.length.times do
        return_string << "<div class='indent'>"
      end

      return_string << if filepath[-1] == "/" # means directory
                         '<span class="glyphicon glyphicon-folder-open"></span> '

                       else
                         '<span class="glyphicon glyphicon-file"></span> '
                       end

      return_string << name_arr.last
      name_arr.length.times do
        return_string << "</div>"
      end
    end

    return_string
  end

  def markdown?
    peek_type == Databank::PeekType::MARKDOWN
  end

  def archive?
    peek_type == Databank::PeekType::LISTING
  end

  def all_txt?
    peek_type == Databank::PeekType::ALL_TEXT
  end

  def part_txt?
    peek_type == Databank::PeekType::PART_TEXT
  end

  def image?
    supported_extensions = %w[avi bmp jp2 jpg jpeg png tif tiff]
    (peek_type == Databank::PeekType::IMAGE) &&
        file_extension &&
        supported_extensions.include?(file_extension)
  end

  def microsoft?
    peek_type == "microsoft"
  end

  def pdf?
    peek_type == "pdf"
  end

  def microsoft_preview_url
    preview_base = "https://view.officeapps.live.com/op/view.aspx?src"
    preview_ref = "https%3A%2F%2Fdatabank.illinois.edu%2Fdatafiles%2F#{web_id}%2Fview"
    return "#{preview_base}=#{preview_ref}" if microsoft?
  end
end
