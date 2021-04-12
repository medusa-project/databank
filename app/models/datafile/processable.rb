# frozen_string_literal: true

module Datafile::Processable
  extend ActiveSupport::Concern

  def initiate_processing_task

    return nil unless Rails.env.production? || Rails.env.demo?

    extractor_task = ExtractorTask.create(web_id: web_id)
    update_attribute(:task_id, extractor_task.id) if extractor_task
  end

  def extractor_task
    return nil unless task_id

    ExtractorTask.find_by(id: task_id)
  end

  def handle_extractor_message(message_text:)
    if message_text["status"] == "success"
      return handle_extractor_success(peek_type: message_text["peek_type"], peek_text: message_text["peek_text"])
    end

    raise("invalid or error response from archive extractor:\n#{message_text}")
  end

  def handle_extractor_success(peek_type:, peek_text:)
    self.peek_text = peek_text
    self.peek_type = peek_type
    save!
  end

  class_methods do
    def set_missing_peek_info
      datafiles = Datafile.where(peek_type: nil)

      datafiles.each do |datafile|
        if !datafile.mime_type || datafile.mime_type == ""
          mime_guesses_set = MIME::Types.type_for(datafile.binary_name.downcase)
          datafile.mime_type = if mime_guesses_set.present?
                                 mime_guesses_set[0].content_type
                               else
                                 "application/octet-stream"
                               end
        end

        initial_peek_type = Datafile.peek_type_from_mime(datafile.mime_type, datafile.binary_size)

        # puts initial_peek_type
        if initial_peek_type
          datafile.peek_type = initial_peek_type
          if initial_peek_type == Databank::PeekType::ALL_TEXT
            all_text_peek = datafile.all_text_peek
            if all_text_peek
              datafile.peek_text = datafile.all_text_peek
            else
              datafile.peek_type = Databank::PeekType::NONE
              datafile.peek_text = nil
            end

          elsif initial_peek_type == Databank::PeekType::PART_TEXT
            part_text_peek = datafile.part_text_peek
            if part_text_peek
              datafile.peek_text = datafile.part_text_peek
            else
              datafile.peek_type = Databank::PeekType::NONE
              datafile.peek_text = nil
            end
          elsif initial_peek_type == Databank::PeekType::MICROSOFT
            datafile.peek_type = initial_peek_type
          elsif initial_peek_type == Databank::PeekType::PDF
            datafile.peek_type = initial_peek_type
          elsif initial_peek_type == Databank::PeekType::IMAGE
            datafile.peek_type = initial_peek_type

          elsif initial_peek_type == Databank::PeekType::LISTING
            datafile.peek_type = Databank::PeekType::NONE
            datafile.initiate_processing_task
          end
        else
          datafile.peek_type = Databank::PeekType::NONE
        end

        begin
          datafile.save
        rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError, ArgumentError
          datafile.peek_type = Databank::PeekType::NONE
          datafile.peek_text = nil
          datafile.save
        end
      end
    end
  end
end
