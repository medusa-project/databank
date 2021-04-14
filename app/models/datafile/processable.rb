# frozen_string_literal: true

module Datafile::Processable
  extend ActiveSupport::Concern

  def initiate_processing_task
    return nil unless Rails.env.production? || Rails.env.demo?

    extractor_task = ExtractorTask.create(web_id: web_id)
    update_attribute(:task_id, extractor_task.id) if extractor_task
  end

  def handle_extractor_message(message_text:)
    message_obj = JSON.parse(message_text)
    if message_obj["status"] == "success"
      return handle_extractor_success(peek_type: message_obj["peek_type"], peek_text: message_obj["peek_text"])
    end

    raise("invalid or error response from archive extractor:\n#{message_text}")
  end

  def handle_extractor_success(peek_type:, peek_text:)
    self.peek_text = peek_text
    self.peek_type = peek_type
    self.save!
  end

end
