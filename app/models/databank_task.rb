# frozen_string_literal: true

require "rest-client"
require 'aws-sdk'
require 'base64'
require 'json'

class DatabankTask
  TASKS_URL = IDB_CONFIG[:tasks_url]


  def self.create_remote(datafile_web_id)
    datafile = Datafile.find_by(web_id: datafile_web_id)
    return nil unless datafile

    endpoint = "#{TASKS_URL}/tasks"
    payload = {task: {web_id:       datafile.web_id,
                      storage_root: datafile.storage_root,
                      storage_key:  datafile.storage_key,
                      binary_name:  datafile.binary_name}}
    response = RestClient.post endpoint, payload
    raise StandardError.new("problem creating task: #{response}") unless response.code == 201

    raise StandardError.new("task keys in response did not include id: #{response_hash.keys}") unless response_has.has_key("id")

    response_hash["id"]
  end

  def self.invoke_lambda(datafile_web_id:)
    datafile = Datafile.find_by(web_id: datafile_web_id)
    return JSON.generate({response: %Q[ERROR -- no datafile for #{datafile_web_id}]}) unless datafile

    client = Aws::Lambda::Client.new(region: IDB_CONFIG[:aws][:region])

    bucket_name = datafile.storage_root_bucket
    object_key = datafile.storage_key_with_prefix
    binary_name = datafile.binary_name
    payload_params = {bucket_name: bucket_name, object_key: object_key, binary_name: binary_name, web_id: datafile_web_id}
    payload = JSON.generate(payload_params)
    response = client.invoke({
                           function_name: 'databank-tasks-demo',
                           invocation_type: 'Event',
                           log_type: 'Tail',
                           payload: payload
                         })

    raise StandardError.new("unexpected response to attempt to invoke tasks lambda: #{response.to_yaml}") unless response.status_code

    return JSON.generate({response: "SUCCESS"}) if response.status_code == 202

    # the happy path is above us -- down here there is only failure and picking up the pieces
    log_string = Base64.decode64(response.log_result)
    error_string = "tasks lambda response for #{datafile_web_id}: #{response.function_error}\n#{log_string}"
    notification = DatabankMailer.error(error_string)
    notification.deliver_now
    JSON.generate({response: %Q[ERROR -- #{error_string}]})
  end

  def self.handle_incoming_messages
    messages = fetch_and_parse_incoming_sqs
    messages.each do |raw_message|
      parsed_message = JSON.parse(raw_message)
      parsed_message.transform_keys!(&:to_sym)
      handle_incoming_message(parsed_message)
    end
  end

  def self.handle_incoming_message(message:)
    validation_report = validation_report(message: message)

    return report_err(type: "invalid", content: validation_report.to_yaml) unless validation_report[:status] == "VALID"

    return report_err(type: "error reported by tasks lambda", content: message[:error]) if message[:status] == "ERROR"

    datafile = Datafile.find_by(web_id: message[:web_id])
    return report_err(type: "datafile not found", content: "for message #{message.to_yaml}") unless datafile

    datafile.update(peek_type=message[:peek_type], peek_text=message[:peek_text])

    message.nested_items.each do |raw_item|
      item = JSON.parse(raw_item)
      NestedItem.create(datafile_id:  datafile.id,
                        item_name:    item["item_name"],
                        item_path:    item["item_path"],
                        media_type:   item["media_type"],
                        size:         item["item_size"],
                        is_directory: item["is_directory"] == "true")
    end
  end

  def self.report_err(type:, content:)
    error_string = "SQS message error\nType: #{type}\nContent: #{content}"
    Rails.logger.warn error_string
    notification = DatabankMailer.error(error_string)
    notification.deliver_now
  end

  # a valid message
  # is a hash (parsed from a json string then keys symbolized)
  # has a status key
  # has a web_id key
  # the status key value is "ERROR" or "SUCCESS"
  # if the status key value is "ERROR", then it also has an error key
  # if the status key value is "SUCCESS", then it also has these keys: peek_type, peek_text, nested_items
  # if it has a nested_item key, then the value is of an array type
  # returns at first error encountered -- report not necessarily comprehensive
  def self.validation_report(message:)
    return {status: "ERROR", error: "nil message"} if message.nil?

    return {status: "ERROR", error: "message not Hash"} unless message.instance_of? Hash

    # all messages must have web_id and status keys
    return {status: "ERROR", error: "missing :web_id key"} unless message.has_key?(:web_id)

    return {status: "ERROR", error: "missing :status key"} unless message.has_key?(:status)

    # status value must be "ERROR" or "SUCCESS"
    return {status: "ERROR", error: "invalid :status value"} unless ["ERROR", "SUCCESS"].include?(message[:status])

    # messages with a status of ERROR must have an error key with String value
    if message[:status] == "ERROR"
      return {status: "ERROR", error: "missing :error key for ERROR"} unless message.has_key?(:error)
    end

    # at this point, we can assume message status is SUCCESS
    return {status: "ERROR", error: "missing :peek_text for SUCCESS"} unless message.has_key?(:peek_text)

    return {status: "ERROR", error: "missing :peek_type for SUCCESS"} unless message.has_key?(:peek_type)

    return {status: "ERROR", error: "missing :nested_items for SUCCESS"} unless message.has_key?(:nested_items)

    return {status: "ERROR", error: ":nested_items not an array"} unless message[:nested_items].instance_of? Array

    valid_item_keys = ["item_name", "item_path", "media_type", "item_size", "is_directory"]
    message[:nested_items].each do |item|
      parsed_item = JSON.parse(item)
      return {status: "ERROR", error: ":nested_item has invalid keyset"} unless parsed_item.keys == valid_item_keys

      return {status: "ERROR", error: "invalid#{item.to_yaml}"} unless ["true", "false"].include?(item[:is_directory])

    end
    {status: "SUCCESS"}
  end

  def self.fetch_and_parse_incoming_sqs_messages
    messages = Array.new
    loop do
      message = fetch_and_parse_incoming_sqs_message
      exit if message.nil?
      messages << message
    end
    messages
  end

  def self.fetch_and_parse_incoming_sqs_message
    sqs = QueueManager.instance.sqs_client
    queue_url = IDB_CONFIG[:queues][:extractor_to_databank_url]
    response = sqs.receive_message(queue_url: queue_url, max_number_of_messages: 1)
    return nil if response.nil?

    message = response.message
    # Delete the message from the queue.
    sqs.delete_message({queue_url: queue_url, receipt_handle: message.receipt_handle})
    message
  end

  def self.all_remote_tasks
    endpoint = "#{TASKS_URL}/tasks"
    response = RestClient.get endpoint
    raise StandardError.new("problem getting all remote tasks: #{response}") unless response.code == 200

    JSON.parse(response)
  end

  def self.pending_tasks
    endpoint = "#{TASKS_URL}/tasks?status=pending"
    response = RestClient.get endpoint
    JSON.parse(response)
  end

  def self.get_remote_task(task_id)
    endpoint = "#{TASKS_URL}/tasks/#{task_id}"
    begin
      response = RestClient.get endpoint
      raise StandardError.new("problem getting remote task for task: #{task_id}") unless response.code == 200

      JSON.parse(response)
    rescue RestClient::NotFound
      raise StandardError.new("task not found for databank task: #{task_id}")
    end
  end

  def self.set_remote_task_status(task_id, new_status)
    endpoint = "#{TASKS_URL}/tasks/#{task_id}"
    payload = {task: {id:     task_id,
                      status: new_status}}
    response = RestClient.patch endpoint, payload
    response.code == 200
  end

  def self.get_remote_items(task_id)
    endpoint = "#{TASKS_URL}/tasks/#{task_id}/nested_items"
    response = RestClient.get endpoint
    raise StandardError.new("Problem getting tasks for task #{task_id}.") unless response.code == 200

    JSON.parse(response)
  end

  def self.problems(task_id)
    endpoint = "#{TASKS_URL}/tasks/#{task_id}/problems"
    response = RestClient.get endpoint
    raise StandardError.new("problem getting problems for task: #{task_id}") unless response.code == 200

    JSON.parse(response)
  end

  def self.problem_comments(task_id, problem_id)
    endpoint = "#{TASKS_URL}/tasks/#{task_id}/problems/#{problem_id}/comments"
    response = RestClient.get endpoint
    raise StandardError.new("problem getting problem comments for task #{task_id} problem #{problem_id}") unless response.code == 200

    JSON.parse(response)
  end

  def self.nested_items(task_id)
    endpoint = "#{TASKS_URL}/tasks/#{task_id}/nested_items"
    response = RestClient.get endpoint
    raise StandardError.new("problem getting nested items for task #{task_id}") unless response.code == 200

    JSON.parse(response)
  end

  def self.fetch_incoming_messages
    raise StandardError.new("not yet implemented")
  end

  def self.handle_incoming_messages(incoming_messages:)
    raise StandardError.new("not yet implemented")
  end
end
