# frozen_string_literal: true

require "rake"
require "bunny"
require "json"
require "mime/types"
require "aws-sdk-sqs"
require "aws-sdk-ecs"
require "securerandom"

include Databank

namespace :databank_tasks do
  desc "get and handle messages from databank-tasks-micro"
  task handle_incoming_messages: :environment do
    incoming_messages = DatabankTask.fetch_incoming_messages
    DatabankTask.handle_incoming_messages(incoming_messages: incoming_messages)
  end

  desc "create test sqs message"
  task make_test_sqs_message: :environment do
    queue_url = "https://sqs.us-east-2.amazonaws.com/721945215539/databank-to-medusa-demo"
    sqs = Aws::SQS::Client.new(region: "us-east-2")
    resp = sqs.send_message(queue_url: queue_url, message_body: "{'content': 'test'}")
    puts resp
  end
  desc "fetch test sqs message"
  task fetch_test_sqs_message: :environment do
    queue_url = "https://sqs.us-east-2.amazonaws.com/721945215539/databank-to-medusa-demo"
    sqs = Aws::SQS::Client.new(region: "us-east-2")
    resp = sqs.receive_message(queue_url: queue_url, max_number_of_messages: 1)
    resp.messages.each do |m|
      puts m.body
      # Delete the message from the queue.
      sqs.delete_message({
                           queue_url:      queue_url,
                           receipt_handle: m.receipt_handle
                         })
    end
  end

  desc "test fargate-based archive extractor"
  task test_extractor: :environment do
    task = {
      cluster:               "databank-archive-extractor-demo",
      count:                 1,
      launch_type:           "FARGATE",
      network_configuration: {
        awsvpc_configuration: {
          subnets:          ["subnet-089d1cf4d18d40f2a", "subnet-075fc9512c9d8f03b"],
          security_groups:  ["sg-073e123a16a0c1d8d"],
          assign_public_ip: "ENABLED",
        },
      },
      overrides:             {
        container_overrides: [
          {
            name:    "databank-archive-extractor-demo-task",
            command: ["ruby", "-r", "./lib/extractor.rb", "-e", "Extractor.extract 'medusa-demo-main', '156/182/DOI-10-5072-fk2idbdev-2148924_v1/dataset_files/datafile1.zip', 'datafile1.zip', 'placeholder'"],
          },
        ],
      },
      platform_version:      "1.4.0",
      task_definition:       "databank-archive-extractor-demo-td:1",
    }
    resp = client.run_task(task)
    puts resp
  end

  desc "invoke demo lambda for test datafile"
  task invoke_test_lambda: :environment do
    puts DatabankTask.invoke_lambda(datafile_web_id: "q0jef")
  end

  # example demo invocation:
  # RAILS_ENV=demo bundle exec rails databank_tasks:invoke_task_lambda[q0jef]
  desc "invoke lambda for specified datafile"
  task :invoke_task_lambda, [:web_id] => :environment do |t, args|
    puts "missing web_id argument" unless args && args[:web_id]
    puts DatabankTask.invoke_lambda(datafile_web_id: args[:web_id])
  end

  desc "fetch, parse, and handle incoming sqs messages"
  task handle_incoming_messages: :environment do
    DatabankTask.handle_incoming_messages
  end

  desc "peek at first sqs message, do not delete"
  task validate_peek: :environment do
    raw_message = DatabankTask.peek_message
    puts "raw_message:\n#{raw_message}"
    parsed_message = JSON.parse(raw_message)
    puts "parsed_message:\n#{parsed_message}"
    parsed_message.transform_keys!(&:to_sym)
    puts "parsed_message with symbolized keys:\n#{parsed_message}"
    puts validation_report(message: parsed_message)
  end

  desc "remove tasks from datafiles"
  task remove_all_tasks: :environment do
    Datafile.all.each do |datafile|
      datafile.task_id = nil
      datafile.save
    end
  end

  desc "set missing peek_info from mime_type and size"
  task set_missing_peek_info: :environment do
    Datafile.set_missing_peek_info
  end

  desc "import nested items and peek info from complete tasks"
  task handle_ripe_tasks: :environment do
    Datafile.all.each do |datafile|
      next unless datafile&.task_id

      task_hash = DatabankTask.get_remote_task(datafile.task_id)

      next unless task_hash.has_key?("status") && task_hash["status"] == TaskStatus::RIPE

      # claim tasks
      DatabankTask.set_remote_task_status(datafile.task_id, TaskStatus::HARVESTING)

      datafile.peek_type = if task_hash.has_key?("peek_type")
                             task_hash["peek_type"]
                           else
                             Databank::PeekType::NONE
                           end

      datafile.peek_text = if task_hash.has_key?("peek_text") && !task_hash["peek_text"].nil?
                             task_hash["peek_text"].encode("utf-8")
                           else
                             ""
                           end

      datafile.save

      if datafile.peek_type == Databank::PeekType::LISTING

        remote_nested_items = DatabankTask.get_remote_items(datafile.task_id)
        remote_nested_items.each do |item|
          existing_items = NestedItem.where(datafile_id: datafile.id, item_path: item["item_path"])

          existing_items.each(&:destroy) if existing_items.count > 0

          NestedItem.create(datafile_id:  datafile.id,
                            item_name:    item["item_name"],
                            item_path:    item["item_path"],
                            media_type:   item["media_type"],
                            size:         item["item_size"],
                            is_directory: item["is_directory"] == "true")
        end

      end

      # close tasks
      DatabankTask.set_remote_task_status(datafile.task_id, TaskStatus::HARVESTED)
    end
  end

  desc "reset test harvesting tasks back to ripe"
  task set_ripe: :environment do
    Datafile.all.each do |datafile|
      next unless datafile&.task_id

      task_hash = DatabankTask.get_remote_task(datafile.task_id)
      if task_hash.has_key?("status") && task_hash["status"] == TaskStatus::HARVESTING
        DatabankTask.set_remote_task_status(datafile.task_id, TaskStatus::RIPE)
      end
    end
  end

  desc "list local queues"
  task list_local_queues: :environment do
    puts "Hello local queues"
    sqs = Aws::SQS::Client.new(
      endpoint: "http://localhost:9324/",
      region:   "us-east-2"
    )

    queues = sqs.list_queues

    puts queues.to_yaml

    puts "Goodbye local queues"
  end
end
