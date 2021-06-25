# frozen_string_literal: true

class ExtractorTask < ApplicationRecord

  has_one :extractor_response, dependent: :destroy

  QUEUE_URL = IDB_CONFIG[:queues][:extractor_to_databank_url]
  SQS = QueueManager.instance.sqs_client
  MESSAGE_ROOT = StorageManager.instance.message_root
  ECS_CLIENT = ContainerManager.instance.ecs_client
  CLUSTER = IDB_CONFIG[:extractor][:cluster]
  MAX_TASK_COUNT = 49
  MAX_BATCH_COUNT = 9

  def initiate_task
    client = ECS_CLIENT
    task = {
      cluster:               CLUSTER,
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
    raise StandardError.new("error in Extractor Task for #{web_id}: #{resp}") unless failure_count.zero?

    update(sent_at: Time.current)
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
               "', '",
               datafile.mime_type,
               "'"]
    str_arr.join
  end

  def datafile
    Datafile.find_by(web_id: web_id)
  end

  def self.initiate_task_batch
    unsent = ExtractorTask.where(sent_at: nil)
    return nil unless unsent.count.positive?

    current_task_count = ExtractorTask.current_tasks.count
    return nil unless current_task_count < MAX_TASK_COUNT

    task_capacity = MAX_TASK_COUNT - current_task_count
    to_send = unsent.limit([task_capacity, MAX_BATCH_COUNT].min)
    to_send.map(&:initiate_task)
  end

  def self.current_tasks
    task_list = ECS_CLIENT.list_tasks(cluster: CLUSTER)
    raise StandardError.new("unexpected task_list: #{task_list.to_yaml.to_s}") unless task_list.task_arns

    task_list.task_arns
  end

  def self.fetch_incoming_message
    response = SQS.receive_message(queue_url: QUEUE_URL, max_number_of_messages: 1)
    return nil if response.data.messages.count.zero?

    message = JSON.parse(response.data.messages[0].body)
    SQS.delete_message({queue_url: QUEUE_URL, receipt_handle: response.data.messages[0].receipt_handle})

    key = message["object_key"]
    parsed_key = key.split("/").last

    message_web_id = parsed_key.split(".").first
    raise StandardError.new("extractor task message not found for #{message}") unless MESSAGE_ROOT.exist?(parsed_key)

    message_text = MESSAGE_ROOT.as_string(parsed_key)
    MESSAGE_ROOT.delete_content(parsed_key)
    {message_web_id: message_web_id, message_text: message_text}
  end

  def self.handle_incoming_message(message_web_id:, message_text:)
    datafile = Datafile.find_by(web_id: message_web_id)
    raise StandardError.new("no Datafile found for archive extractor response message: #{message}") unless datafile

    ExtractorTask.record_response(datafile: datafile, message_text: message_text)
  end

  def self.record_response(datafile:, message_text:)
    extractor_task = datafile.extractor_task
    raise StandardError.new("no extractor_task:\n#{message_text}") if extractor_task.nil?

    extractor_task.response_at = Time.current
    extractor_task.raw_response = message_text
    extractor_task.save
    message = JSON.parse(message_text)
    extractor_response = ExtractorResponse.create(extractor_task_id: extractor_task.id,
                                                  web_id:            message["web_id"],
                                                  status:            message["status"],
                                                  peek_type:         message["peek_type"],
                                                  peek_text:         message["peek_text"])
    raise StandardError("invalid #{message_text}") unless extractor_response.valid?

    success_response = extractor_response["status"] == Databank::ExtractionStatus::SUCCESS
    raise StandardError.new(extractor_response.to_yaml.to_s) unless success_response

    datafile.update(peek_type: extractor_response.peek_type, peek_text: extractor_response.peek_text)
    ExtractorTask.handle_extracted_nested_items(datafile: datafile, nested_items: message["nested_items"])
  end

  def self.handle_extracted_nested_items(datafile:, nested_items:)
    return nil unless nested_items.respond_to?(:each) && nested_items.count.positive?

    datafile.nested_items.destroy_all
    nested_items.each do |item|
      NestedItem.create!(datafile_id:  datafile.id,
                         item_name:    item["item_name"],
                         item_path:    item["item_path"],
                         media_type:   item["media_type"],
                         size:         item["item_size"],
                         is_directory: item["is_directory"] == "true")
    end
  end
end
