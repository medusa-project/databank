require 'rake'
require 'bunny'
require 'json'

namespace :testing do

  desc 'send a RabbitMQ message'
  task :send_msg => :environment do
    puts "sending message"

    config = (AMQP_CONFIG || {}).symbolize_keys

    config.merge!(recover_from_connection_close: true)

    conn = Bunny.new(config)
    conn.start

    ch = conn.create_channel
    q = ch.queue("idb_to_medusa", :durable => true)
    x = ch.default_exchange

    # q.subscribe do |delivery_info, metadata, payload|
    #   puts "Received #{payload}"
    # end

    x.publish("This might be a message.", :routing_key => q.name)

    conn.close

  end

  desc 'get a RabbitMQ message'
  task :get_msg => :environment do
    puts "getting message"

    config = (AMQP_CONFIG || {}).symbolize_keys

    config.merge!(recover_from_connection_close: true)

    conn = Bunny.new(config)
    conn.start

    ch = conn.create_channel
    q = ch.queue("medusa_to_idb", :durable => true)
    x = ch.default_exchange

    delivery_info, properties, payload = q.pop
    if payload.nil?
      puts "No message found."
    else
      puts "This is the message: " + payload + "\n\n"
    end

    conn.close

  end

  desc 'simulate RabbitMQ ok response from Medusa'
  task :send_ok => :environment do
    puts "sending message"

    config = (AMQP_CONFIG || {}).symbolize_keys

    config.merge!(recover_from_connection_close: true)

    conn = Bunny.new(config)
    conn.start

    ch = conn.create_channel
    q = ch.queue("medusa_to_idb", :durable => true)
    x = ch.default_exchange

    # q.subscribe do |delivery_info, metadata, payload|
    #   puts "Received #{payload}"
    # end

    msg_hash = {status: 'ok',
                operation: 'ingest',
                staging_path: 'uploads/5g06s/test.txt',
                medusa_path: '5g06s_test.txt',
                medusa_uuid: '149603bb-0cad-468b-9ef0-e91023a5d455',
                error: ''}

    x.publish("#{msg_hash.to_json}", :routing_key => q.name)

    conn.close

  end

  desc 'simulate RabbitMQ error response from Medusa'
  task :send_error => :environment do
    puts "sending message"

    config = (AMQP_CONFIG || {}).symbolize_keys

    config.merge!(recover_from_connection_close: true)

    conn = Bunny.new(config)
    conn.start

    ch = conn.create_channel
    q = ch.queue("medusa_to_idb", :durable => true)
    x = ch.default_exchange

    # q.subscribe do |delivery_info, metadata, payload|
    #   puts "Received #{payload}"
    # end

    msg_hash = {status: 'error',
                operation: 'ingest',
                staging_path: 'uploads/tbzaq/test.txt',
                medusa_path: '',
                medusa_uuid: '',
                error: 'malformed thingy'}

    x.publish("#{msg_hash.to_json}", :routing_key => q.name)

    conn.close

  end

  desc 'expose license info array'
  task :list_info => :environment do
    LICENSE_INFO_ARR.each do |info|
      puts info.to_yaml
    end
  end

  desc 'hit quest directory service'
  task :blast_directory => :environment do
    Creator.all.each do |creator|
      puts creator.email

      next if creator.email.nil?

      email_parts = creator.email.split("@")
      next unless email_parts.last == 'illinois.edu'

      netid = email_parts.first
      begin
        puts "checking #{netid}"
        open("https://quest.library.illinois.edu/directory/ed/person/#{netid}").read
      rescue OpenURI::HTTPError
        puts "netid #{netid} not found"
      end
    end

  end

end