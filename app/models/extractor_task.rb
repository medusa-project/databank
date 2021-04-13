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

  # retrieves, parses, processes, and deletes a message
  def self.handle_response
    response = SQS.receive_message(queue_url: QUEUE_URL, max_number_of_messages: 1)
    # TEMPORARY DEBUG LOGGING
    Rails.logger.warn QUEUE_URL
    Rails.logger.warn "message count: #{response.data.messages.count}"
    return nil if response.data.messages.count.zero?

    Rails.logger.warn "message 0:"
    Rails.logger.warn response.data.messages[0].to_yaml

    message = JSON.parse(response.data.messages[0].body)
    SQS.delete_message({queue_url: QUEUE_URL, receipt_handle: response.data.messages[0].receipt_handle})
    datafile = Datafile.find_by(message["web_id"])
    raise("no Datafile found for archive extractor response message: #{message}") unless datafile

    key = message["object_key"]
    parsed_key = key.split("/").last
    raise("extractor task message not found for #{datafile.web_id}") unless MESSAGE_ROOT.exist?(parsed_key)

    message_text = MESSAGE_ROOT.as_string(parsed_key)
    MESSAGE_ROOT.delete_content(parsed_key)
    extractor_task = datafile.extractor_task
    raise("no extractor_task for datafile: #{message["web_id"]}\nMSG: #{message_text}") unless extractor_task

    extractor_task.record_response(message: message)

    datafile.handle_extractor_message(message_text: message_text)
  end

  def record_reponse(message:)
    self.response_at = Time.current
    self.response = message
    save!
  end
end
