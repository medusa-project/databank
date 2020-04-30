# frozen_string_literal: true

class SystemMessage

  def self.read_only_message
    msg_first = %(<p>Illinois Data Bank maintenance--<strong>datasets cannot be added or edited.</strong>)
    msg_last = %(<br/><a href="/help#contact" target="_blank">Contact Research Data Service</a> with questions.</p>)
    msg_middle = SystemMessage.read_only_msg_middle

    return msg_first + " " + msg_last if msg_middle.blank?

    msg_first + " " + msg_middle + " " + msg_last
  end

  def self.read_only_msg_middle
    msg_path = IDB_CONFIG[:read_only_msg_path]
    return nil unless File.file?(msg_path)

    msg_middle = File.read(msg_path)
    msg_middle.strip!
    return nil if msg_middle.blank?

    msg_middle
  end

  def self.update_read_only_message(new_message)
    return false if new_message.blank?
    return false unless remove_read_only_message

    msg_path = IDB_CONFIG[:read_only_msg_path]
    worked = false
    File.open(msg_path, "w") do |file|
      bytes_written = file.write(new_message)
      worked = bytes_written.positive?
    end
    worked
  end

  def self.remove_read_only_message
    msg_path = IDB_CONFIG[:read_only_msg_path]
    return true unless File.exist?(msg_path)

    return false unless File.file?(msg_path)

    File.delete(msg_path)
    # return true if file does not exist and return false if file exists
    !File.exist?(msg_path)
  end
end
