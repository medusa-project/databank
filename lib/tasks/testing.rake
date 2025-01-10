# frozen_string_literal: true

require "rake"
require "bunny"
require "json"

namespace :testing do

  desc "add seed binaries to bucket"
  task store_seed_datafiles: :environment do
    puts "adding seed binaries to bucket"

    source_root = "test/fixtures/files"
    Datafile.all.each do |datafile|
      File.open(File.join(source_root, datafile.binary_name), "rb") do |file|
        case datafile.storage_root
        when "draft"
          root = StorageManager.instance.draft_root
        when "medusa"
          root = StorageManager.instance.medusa_root
        else
          raise "invalid storage root for datafile web_id: #{datafile.web_id}, id: #{datafile.id}"
        end
        key = "#{root.prefix}#{datafile.storage_key}"
        # next if object with key already exists
        begin
          Application.aws_client.get_object(bucket: root.bucket, key: key)
          puts "object with key #{key} already exists"
          next
        rescue Aws::S3::Errors::NoSuchKey
          puts "uploading #{key}"
        end
        Aws::S3::Resource.new(client: Application.aws_client).bucket(root.bucket).object(key).upload_file(file)
      end
    end

  end

  desc "send a RabbitMQ message"
  task send_msg: :environment do
    puts "sending message"

    config = (AMQP_CONFIG || {}).symbolize_keys

    config.merge!(recover_from_connection_close: true)

    conn = Bunny.new(config)
    conn.start

    ch = conn.create_channel
    q = ch.queue("idb_to_medusa", durable: true)
    x = ch.default_exchange

    # q.subscribe do |delivery_info, metadata, payload|
    #   puts "Received #{payload}"
    # end

    x.publish("This might be a message.", routing_key: q.name)

    conn.close

  end

  desc "get a RabbitMQ message"
  task get_msg: :environment do
    puts "getting message"

    config = (AMQP_CONFIG || {}).symbolize_keys

    config.merge!(recover_from_connection_close: true)

    conn = Bunny.new(config)
    conn.start

    ch = conn.create_channel
    q = ch.queue("medusa_to_idb", durable: true)
    x = ch.default_exchange

    delivery_info, properties, payload = q.pop
    if payload.nil?
      puts "No message found."
    else
      puts "This is the message: " + payload + "\n\n"
    end

    conn.close

  end

  desc "simulate RabbitMQ ok response from Medusa"
  task send_ok: :environment do
    puts "sending message"

    config = (AMQP_CONFIG || {}).symbolize_keys

    config.merge!(recover_from_connection_close: true)

    conn = Bunny.new(config)
    conn.start

    ch = conn.create_channel
    q = ch.queue("medusa_to_idb", durable: true)
    x = ch.default_exchange

    # q.subscribe do |delivery_info, metadata, payload|
    #   puts "Received #{payload}"
    # end

    msg_hash = {status: "ok",
                operation: "ingest",
                staging_path: "uploads/5g06s/test.txt",
                medusa_path: "5g06s_test.txt",
                medusa_uuid: "149603bb-0cad-468b-9ef0-e91023a5d455",
                error: ""}

    x.publish("#{msg_hash.to_json}", routing_key: q.name)

    conn.close

  end

  desc "simulate RabbitMQ error response from Medusa"
  task send_error: :environment do
    puts "sending message"

    config = (AMQP_CONFIG || {}).symbolize_keys

    config.merge!(recover_from_connection_close: true)

    conn = Bunny.new(config)
    conn.start

    ch = conn.create_channel
    q = ch.queue("medusa_to_idb", durable: true)
    x = ch.default_exchange

    # q.subscribe do |delivery_info, metadata, payload|
    #   puts "Received #{payload}"
    # end

    msg_hash = {status: "error",
                operation: "ingest",
                staging_path: "uploads/tbzaq/test.txt",
                medusa_path: "",
                medusa_uuid: "",
                error: "malformed thingy"}

    x.publish("#{msg_hash.to_json}", routing_key: q.name)

    conn.close

  end

  desc "expose license info array"
  task list_info: :environment do
    LICENSE_INFO_ARR.each do |info|
      puts info.to_yaml
    end
  end

  desc "hit quest directory service"
  task blast_directory: :environment do
    Creator.all.each do |creator|
      next if creator.email.nil?

      next unless creator.email[-12..] == "illinois.edu"

      netid = creator.email.split("@").first
      begin
        puts "checking #{netid}"
        open("https://iisdev1.library.illinois.edu/Directory/ed/person/#{netid}").read
        puts "OK"
      rescue OpenURI::HTTPError
        puts "netid #{netid} not found"
      end
    end
  end
end