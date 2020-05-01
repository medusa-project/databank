# frozen_string_literal: true

module Datafile::Viewable
  extend ActiveSupport::Concern

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
