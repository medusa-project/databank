# frozen_string_literal: true

require "rake"
require "bunny"
require "json"
require "mime/types"
require "aws-sdk-sqs"
require "aws-sdk-ecs"
require "securerandom"

include Databank

namespace :extractor_tasks do
  desc "get and handle message from Illinois Data Bank Archive Extractor"
  task get_extractor_response: :environment do
    msg = ExtractorTask.fetch_incoming_message
    unless msg.nil?
      ExtractorTask.handle_incoming_message(message_web_id: msg[:message_web_id], message_text: msg[:message_text])
    end
  end

  desc "test fargate-based archive extractor"
  task test_extractor: :environment do
    client = Aws::ECS::Client.new(
      region: "us-east-2",
      )
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

  desc "initiate as many tasks as we have up to cluster max"
  task send_batch: :environment do
    ExtractorTask.initiate_task_batch
  end

  desc "backfill sent_at datetime for existing records for new column"
  task backfill_sent: :environment do
    extractor_tasks = ExtractorTask.where(sent_at: nil).where.not(response_at: nil)
    extractor_tasks.each do |extractor_task|
      extractor_task.sent_at = Time.current
      puts "extractor task #{extractor_task.id.to_s} updated: #{extractor_task.save.to_s}"
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

  desc "test local-docker-based archive extractor"
  task test_local_extractor: :environment do
    begin
      network = "databank_default"
      docker_container = "ghcr.io/medusa-project/databank-archive-extractor:local"
      unsent = ExtractorTask.where(sent_at: nil).select(:web_id).distinct

      puts "Extracting #{unsent.count} local archives"
      unsent.each do |extractor_task|
        datafile = Datafile.where(web_id: extractor_task.web_id).first
        puts "Extracting file with web_id: #{extractor_task.web_id}"
        command = "Extractor.extract '#{datafile.storage_root_bucket}', '#{datafile.storage_key_with_prefix}', '#{datafile.binary_name}', '#{datafile.web_id}', '#{datafile.mime_type}'"
        resp =  `docker run --network #{network} #{docker_container} ruby -r ./lib/extractor.rb -e "#{command}"`
        puts resp
        Rake::Task["extractor_tasks:get_extractor_response"].execute
      end
    rescue StandardError => ex
      puts "Error testing extractor #{ex.message}"
    ensure
      Rake::Task["extractor_tasks:backfill_sent"].execute
    end

   end
end
