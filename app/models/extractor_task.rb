# frozen_string_literal: true

class ExtractorTask < ApplicationRecord
  after_create :initiate_task

  QUEUE_URL = IDB_CONFIG[:queues][:extractor_to_databank_url]
  SQS = QueueManager.instance.sqs_client
  MESSAGE_ROOT = StorageManager.instance.message_root

  def initiate_task
    client = ContainerManager.instance.ecs_client
    task = {
      cluster:               IDB_CONFIG[:extractor][:cluster],
      count:                 1,
      launch_type:           "FARGATE",
      network_configuration: {
        awsvpc_configuration: {
          subnets:          IDB_CONFIG[:extractor][:subnets],
          security_groups:  IDB_CONFIG[:extractor][:security_groups],
          assign_public_ip: "ENABLED"
        }
      },
      overrides:             {
        container_overrides: [
          {
            name:    IDB_CONFIG[:extractor][:container_name],
            command: ["ruby",
                      "-r",
                      "./lib/extractor.rb",
                      "-e",
                      command_string]
          }
        ]
      },
      platform_version:      IDB_CONFIG[:extractor][:platform_version],
      task_definition:       IDB_CONFIG[:extractor][:task_definition]
    }
    resp = client.run_task(task)
    failure_count = resp[:failures].count
    raise("error in Extractor Task for #{web_id}: #{resp}") unless failure_count.zero?
  end

  def command_string
    str_arr = ["Extractor.extract '",
               datafile.storage_root_bucket,
               "', '",
               datafile.storage_key_with_prefix,
               "', '",
               datafile.binary_name,
               "', '",
               datafile.web_id,
               "'"]
    str_arr.join
  end

  def datafile
    Datafile.find_by(web_id: web_id)
  end

  def self.fetch_incoming_message
    response = SQS.receive_message(queue_url: QUEUE_URL, max_number_of_messages: 1)
    return nil if response.data.messages.count.zero?

    message = JSON.parse(response.data.messages[0].body)
    SQS.delete_message({queue_url: QUEUE_URL, receipt_handle: response.data.messages[0].receipt_handle})

    key = message["object_key"]
    parsed_key = key.split("/").last

    message_web_id = parsed_key.split(".").first
    raise("extractor task message not found for #{message}") unless MESSAGE_ROOT.exist?(parsed_key)

    message_text = MESSAGE_ROOT.as_string(parsed_key)
    MESSAGE_ROOT.delete_content(parsed_key)
    # TEMPORARY DEBUG LOGGING
    Rails.logger.warn "fetch_incoming_message: {message_web_id: #{message_web_id}, message_text: #{message_text}}"
    {message_web_id: message_web_id, message_text: message_text}
  end

  def self.handle_incoming_message(message_web_id:, message_text:)
    # TEMPORARY DEBUG LOGGING
    Rails.logger.warn "inside handle_incoming_message {message_web_id: #{message_web_id}, message_text: #{message_text}}"
    datafile = Datafile.find_by(web_id: message_web_id)
    raise("no Datafile found for archive extractor response message: #{message}") unless datafile

    ExtractorTask.record_response(datafile: datafile, message_text: message_text)
    datafile.handle_extractor_message(message_text: message_text)
  end

  def self.record_response(datafile:, message_text:)
    extractor_task = datafile.extractor_task
    raise("no extractor_task for datafile: #{datafile.web_id}\nMSG: #{message_text}") if extractor_task.nil?

    extractor_task.response_at = Time.current
    extractor_task.response = message_text
    extractor_task.save!
  end
end
