require 'rake'
require 'bunny'
require 'json'

namespace :medusa do
  desc 'get Medusa RabbitMQ ingest response messages'
  task :get_medusa_ingest_responses => :environment do

    if IDB_CONFIG[:rabbit_or_sqs] == "sqs"
      loop do
        sqs = QueueManager.instance.sqs_client
        queue_url = IDB_CONFIG[:queues][:databank_to_medusa_url]
        response = sqs.receive_message(queue_url: queue_url, max_number_of_messages: 1)
        exit if response.nil?
        m = response.message
        exit if m.body.nil?
        MedusaIngest.on_medusa_message(m.body)
        # Delete the message from the queue.
        sqs.delete_message({queue_url: queue_url, receipt_handle: m.receipt_handle})
      end
    else
      loop do
        AmqpHelper::Connector[:databank].with_message(MedusaIngest.incoming_queue) do |payload|
          exit if payload.nil?
          MedusaIngest.on_medusa_message(payload)
        end
      end
    end
  end

  desc 'update medusa_path of datafile from ingest'
  task :update_paths => :environment do
    datafiles = Datafile.all
    datafiles.each do |df|

      if !df.binary && !df.medusa_path
        puts "web_id: #{df.web_id}"
        puts "no binary or no medusa_path"
        ingest = MedusaIngest.find_by_idb_identifier(df.web_id)
        if ingest
          puts "has ingest"
          df.medusa_path = ingest.medusa_path
          df.save
        else
          puts "has no ingest"
        end

      elsif df.binary && !df.medusa_path
        puts "web_id: #{df.web_id}"
        puts "binary but no medusa path"
        ingest = MedusaIngest.find_by_idb_identifier(df.web_id)
        if ingest
          puts "has ingest"

          effective_binary_path_str = df.binary.path.to_s
          effective_medusa_path_str = "#{IDB_CONFIG['medusa']['medusa_path_root']}/#{ingest.medusa_path}".to_s

          puts "binary: #{effective_binary_path_str}"
          puts "medusa: #{effective_medusa_path_str}"

          if File.exists?(effective_medusa_path_str) && File.exists?(effective_binary_path_str) && FileUtils.identical?(Pathname.new(effective_medusa_path_str), Pathname.new(effective_binary_path_str))
            df.medusa_path = ingest.medusa_path
            df.medusa_id = ingest.medusa_uuid
            df.remove_binary!
            df.save
          else
            puts "first pass of file validation failed"
          end

          if File.exists?(effective_medusa_path_str) && !File.exists?(effective_binary_path_str)
            df.medusa_path = ingest.medusa_path
            df.medusa_id = ingest.medusa_uuid
            df.remove_binary!
            df.save
          else
            puts "missing binary file but file exists in Medusa"
          end

        else
          puts "has no ingest for web_id: #{df.web_id}"
        end
      end
    end
  end

  desc 'resend failed medusa messages'
  task :retry_failed => :environment do
    failed_ingests = MedusaIngest.where(request_status: 'error')
    failed_ingests.each do |ingest|

      ingest.request_status = 'resent'
      ingest.error_text = ''
      ingest.response_time = ''
      ingest.send_medusa_ingest_message(ingest.staging_path)
      ingest.save

    end
  end

  desc 'retroactively set medusa_dataset_dir in dataset if it exist in ingest'
  task :retry_set_dir => :environment do
    ingests = MedusaIngest.where.not(medusa_dataset_dir: nil)
    ingests.each do |ingest|
      if ingest.idb_class == 'datafile'
        datafile = Datafile.find_by_web_id(ingest.idb_identifier)

        dataset = Dataset.where(id: datafile.dataset_id).first

        unless dataset
          Rails.logger.warn "dataset not found for ingest #{ingest.to_yaml}"
        end

        medusa_dataset_dir_json = JSON.parse((ingest.medusa_dataset_dir).gsub("'", '"').gsub('=>', ':'))

        if dataset && (!dataset.medusa_dataset_dir || dataset.medusa_dataset_dir == '')
          dataset.medusa_dataset_dir = medusa_dataset_dir_json['url_path']
          dataset.save
        end


      end
    end
  end

  desc 'resend messages not sent'
  task :retry_medusa_sends => :environment do
    puts 'not yet implemented'
  end

  desc 'update keys from ingests'
  task :update_keys_from_ingests => :environment do

    medusa_root = StorageManager.instance.medusa_root

    MedusaIngest.where.not(medusa_path: nil) do |ingest|
      if ingest.idb_class == 'dataset' && ingest.idb_identifier && ingest.idb_identifier != ''
        dataset = Dataset.find_by_key(ingest.idb_identifier)

        if dataset && medusa_root.exist?(ingest.medusa_path)
          dataset.root = 'medusa'
          dataset.key = ingest.medusa_path
        end
      end
    end
  end


end
