# frozen_string_literal: true

module Messagable
  extend ActiveSupport::Concern

  class_methods do
    def read_only_message
      msg_first = %Q[Illinois Data Bank system is undergoing maintenance, and <strong>datasets cannot currently be added or edited.</strong>]
      msg_last = %Q[<br/>Please <a href="/help#contact" target="_blank">contact the Research Data Service Team</a> with questions.]
      msg_path = IDB_CONFIG[:read_only_msg_path]
      return msg_first + msg_last unless File.file?(msg_path)

      msg_middle = File.read(msg_path)
      msg_middle.strip!
      return msg_first + " " + msg_last unless msg_middle.present?

      msg_first + " " + msg_middle + " " + msg_last
    end

    def update_read_only_message(new_message)
      return false unless new_message.present?
      return false unless remove_read_only_message

      msg_path = IDB_CONFIG[:read_only_msg_path]
      worked = false
      File.open(msg_path, 'w') do |f|
        bytes_written = file.write(new_message)
        worked = bytes_written > 0
      end
      worked
    end

    def remove_read_only_message
      msg_path = IDB_CONFIG[:read_only_msg_path]
      return true unless File.exist?(msg_path)

      return false unless File.file?(msg_path)

      File.delete(msg_path)

      # return true if file does not exist and return false if file exists
      return !File.exist?(msg_path)

    end
  end

end
