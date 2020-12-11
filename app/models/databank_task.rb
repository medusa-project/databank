# frozen_string_literal: true

require "rest-client"
require 'aws-sdk'

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
    raise("problem creating task: #{response}") unless response.code == 201

    raise("task keys in response did not include id: #{response_hash.keys}") unless response_has.has_key("id")

    response_hash["id"]
  end

  def self.invoke_lambda(datafile_web_id)
    datafile = Datafile.find_by(web_id: datafile_web_id)
    return nil unless datafile

    client = Aws::Lambda::Client.new(region: IDB_CONFIG[:aws][:region])

    bucket_name = datafile.storage_root_bucket
    object_key = datafile.storage_key_with_prefix
    binary_name = datafile.binary_name
    payload_params = {bucket_name: bucket_name, object_key: object_key, binary_name: binary_name}
    payload = JSON.generate(payload_params)
    response = client.invoke({
                           function_name: 'databank-tasks-demo',
                           invocation_type: 'DryRun',
                           log_type: 'None',
                           payload: payload
                         })

    response_status = JSON.parse(response.StatusCode)
    puts response_status
    response_payload = JSON.parse(response.payload.string) # , symbolize_names: true)
    puts response_payload
  end

  def self.all_remote_tasks
    endpoint = "#{TASKS_URL}/tasks"
    response = RestClient.get endpoint
    raise("problem getting all remote tasks: #{response}") unless response.code == 200

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
      raise("problem getting remote task for task: #{task_id}") unless response.code == 200

      JSON.parse(response)
    rescue RestClient::NotFound
      raise("task not found for databank task: #{task_id}")
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
    raise("Problem getting tasks for task #{task_id}.") unless response.code == 200

    JSON.parse(response)
  end

  def self.problems(task_id)
    endpoint = "#{TASKS_URL}/tasks/#{task_id}/problems"
    response = RestClient.get endpoint
    raise("problem getting problems for task: #{task_id}") unless response.code == 200

    JSON.parse(response)
  end

  def self.problem_comments(task_id, problem_id)
    endpoint = "#{TASKS_URL}/tasks/#{task_id}/problems/#{problem_id}/comments"
    response = RestClient.get endpoint
    raise("problem getting problem comments for task #{task_id} problem #{problem_id}") unless response.code == 200

    JSON.parse(response)
  end

  def self.nested_items(task_id)
    endpoint = "#{TASKS_URL}/tasks/#{task_id}/nested_items"
    response = RestClient.get endpoint
    raise("problem getting nested items for task #{task_id}") unless response.code == 200

    JSON.parse(response)
  end

  def self.fetch_incoming_messages
    raise("not yet implemented")
  end

  def self.handle_incoming_messages(incoming_messages:)
    raise("not yet implemented")
  end
end
