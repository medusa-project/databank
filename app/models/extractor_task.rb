# frozen_string_literal: true

class ExtractorTask < ApplicationRecord
  after_create :initiate_task

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

  # retrieves and parses message
  def self.fetch_message
    queue_url = IDB_CONFIG[:queues][:extractor_to_databank_url]
    sqs = QueueManager.instance.sqs_client
    response = sqs.receive_message(queue_url: queue_url, max_number_of_messages: 1)
    return {error: "no response"}.to_json if response.nil?

    message = JSON.parse(response.data.messages[0].body)
    Rails.logger.warn(message.keys)
    key = message["object_key"]
    parsed_key = key.split("/").last
    message_text = StorageManager.instance.message_root.as_string("#{parsed_key}")
    Rails.logger.warn message_text
    message_text
  end
end
