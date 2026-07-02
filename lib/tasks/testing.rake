# frozen_string_literal: true

require "rake"
require "bunny"
require "json"

namespace :testing do

  # Seed datasets covering every field the flat exporter touches.
  # Designed to be run after db:fixtures:load to augment the basic fixture data.
  # Creates 3 datasets:
  #   migration_full  – person creator + institutional creator, contributor,
  #                     funder with grant, related material, note, token,
  #                     one datafile with nested items (dir + file tree)
  #   migration_minimal – single creator, no optional associations
  #   migration_multi_file – two datafiles, one with nested items
  #
  # Usage:
  #   bin/rails testing:seed_migration_test_data
  #   bin/rails testing:seed_migration_test_data RESET=true  # destroys existing seed records first
  #
  # After seeding, export with:
  #   bin/rails migration:legacy:export_test_bundle OUTPUT_ROOT=/tmp/migration_test_export
  desc "Create migration test datasets covering all flat export fields"
  task seed_migration_test_data: :environment do
    reset = ENV.fetch("RESET", "false").casecmp("true").zero?
    seed_keys = %w[TESTIDB-MIGRATE1 TESTIDB-MIGRATE2 TESTIDB-MIGRATE3]

    if reset
      Dataset.where(key: seed_keys).each do |ds|
        NestedItem.where(datafile_id: ds.datafiles.pluck(:id)).delete_all
        ds.datafiles.delete_all
        ds.creators.delete_all
        ds.contributors.delete_all
        ds.funders.delete_all
        ds.related_materials.delete_all
        ds.notes.delete_all
        Token.where(dataset_key: ds.key).delete_all
        ds.delete
      end
      puts "Reset: removed existing seed records."
    end

    # ── Dataset 1: full coverage ────────────────────────────────────────────
    ds1 = Dataset.find_or_create_by!(key: "TESTIDB-MIGRATE1") do |d|
      d.title               = "Migration Test: Full Coverage Dataset"
      d.identifier          = ""
      d.publisher           = "University of Illinois Urbana-Champaign"
      d.description         = "Seed dataset for testing the flat NDJSON export and import pipeline."
      d.license             = "CC01"
      d.depositor_name      = "Researcher One"
      d.depositor_email     = "researcher1@mailinator.com"
      d.corresponding_creator_name = "Researcher One"
      d.publication_state   = "released"
      d.hold_state          = "none"
      d.embargo             = "none"
      d.is_test             = true
      d.is_import           = false
      d.dataset_version     = "1"
      d.subject             = "Other"
      d.keywords            = "migration; test; flat format"
      d.release_date        = Date.today
    end

    ds1.creators.find_or_create_by!(family_name: "One", given_name: "Researcher") do |c|
      c.email             = "researcher1@mailinator.com"
      c.identifier        = "0000-0001-2345-6789"
      c.identifier_scheme = "ORCID"
      c.is_contact        = true
      c.row_position      = 0
      c.type_of           = 0
    end
    ds1.creators.find_or_create_by!(institution_name: "Test Institution") do |c|
      c.email        = "test-institution@example.com"
      c.is_contact   = false
      c.row_position = 1
      c.type_of      = 1
    end

    ds1.contributors.find_or_create_by!(family_name: "Helper", given_name: "Test") do |c|
      c.email             = "helper@example.com"
      c.identifier        = "0000-0002-3456-7890"
      c.identifier_scheme = "ORCID"
      c.row_position      = 0
      c.type_of           = 0
    end

    ds1.funders.find_or_create_by!(name: "National Science Foundation") do |f|
      f.identifier        = "https://doi.org/10.13039/100000001"
      f.identifier_scheme = "ISNI"
      f.grant             = "NSF-2024-TEST-001"
    end

    ds1.related_materials.find_or_create_by!(uri: "https://example.com/related-paper") do |m|
      m.material_type = "article"
      m.selected_type = "doi"
      m.availability  = "available"
      m.link          = "https://example.com/related-paper"
      m.citation      = "Test Author. 2024. Related Paper. Test Journal."
      m.datacite_list = "IsSupplementTo"
    end

    ds1.notes.find_or_create_by!(author: "curator@example.com") do |n|
      n.body = "This is a curator note for migration testing."
    end

    Token.find_or_create_by!(dataset_key: ds1.key) do |t|
      t.identifier = SecureRandom.uuid
      t.expires    = 1.year.from_now
    end

    df1 = ds1.datafiles.find_or_create_by!(binary_name: "test_archive.zip") do |f|
      f.web_id       = "migrate1a"
      f.binary_size  = 1024
      f.storage_root = "draft"
      f.storage_key  = "migrate-test/test_archive.zip"
      f.peek_type    = "notsupported"
    end

    # Nested items: a small simulated zip tree
    root_dir = NestedItem.find_or_create_by!(datafile_id: df1.id, item_name: "archive", parent_id: nil) do |ni|
      ni.item_path    = "archive/"
      ni.is_directory = true
      ni.media_type   = "inode/directory"
      ni.size         = 0
    end
    sub_dir = NestedItem.find_or_create_by!(datafile_id: df1.id, item_name: "data", parent_id: root_dir.id) do |ni|
      ni.item_path    = "archive/data/"
      ni.is_directory = true
      ni.media_type   = "inode/directory"
      ni.size         = 0
    end
    NestedItem.find_or_create_by!(datafile_id: df1.id, item_name: "results.csv", parent_id: sub_dir.id) do |ni|
      ni.item_path    = "archive/data/results.csv"
      ni.is_directory = false
      ni.media_type   = "text/csv"
      ni.size         = 512
    end
    NestedItem.find_or_create_by!(datafile_id: df1.id, item_name: "readme.txt", parent_id: root_dir.id) do |ni|
      ni.item_path    = "archive/readme.txt"
      ni.is_directory = false
      ni.media_type   = "text/plain"
      ni.size         = 128
    end

    puts "Created dataset 1: #{ds1.key} (full coverage, #{NestedItem.where(datafile_id: df1.id).count} nested items)"

    # ── Dataset 2: minimal (single creator, no optional associations) ────────
    ds2 = Dataset.find_or_create_by!(key: "TESTIDB-MIGRATE2") do |d|
      d.title               = "Migration Test: Minimal Dataset"
      d.identifier          = ""
      d.publisher           = "University of Illinois Urbana-Champaign"
      d.description         = "Minimal seed dataset: single creator, no funders, notes, or token."
      d.license             = "CC01"
      d.depositor_name      = "Researcher Two"
      d.depositor_email     = "researcher2@mailinator.com"
      d.corresponding_creator_name = "Researcher Two"
      d.publication_state   = "draft"
      d.hold_state          = "none"
      d.embargo             = "none"
      d.is_test             = true
      d.is_import           = false
      d.dataset_version     = "1"
    end

    ds2.creators.find_or_create_by!(family_name: "Two", given_name: "Researcher") do |c|
      c.email        = "researcher2@mailinator.com"
      c.is_contact   = true
      c.row_position = 0
      c.type_of      = 0
    end

    ds2.datafiles.find_or_create_by!(binary_name: "hello.rb") do |f|
      f.web_id       = "migrate2a"
      f.binary_size  = 64
      f.storage_root = "draft"
      f.storage_key  = "migrate-test/hello.rb"
      f.peek_type    = "code"
    end

    puts "Created dataset 2: #{ds2.key} (minimal)"

    # ── Dataset 3: multi-file, one with nested items ──────────────────────────
    ds3 = Dataset.find_or_create_by!(key: "TESTIDB-MIGRATE3") do |d|
      d.title               = "Migration Test: Multi-File Dataset"
      d.identifier          = ""
      d.publisher           = "University of Illinois Urbana-Champaign"
      d.description         = "Seed dataset with two datafiles, one containing nested items."
      d.license             = "CC01"
      d.depositor_name      = "Researcher One"
      d.depositor_email     = "researcher1@mailinator.com"
      d.corresponding_creator_name = "Researcher One"
      d.publication_state   = "released"
      d.hold_state          = "none"
      d.embargo             = "none"
      d.is_test             = true
      d.is_import           = false
      d.dataset_version     = "1"
      d.release_date        = Date.today
    end

    ds3.creators.find_or_create_by!(family_name: "One", given_name: "Researcher") do |c|
      c.email        = "researcher1@mailinator.com"
      c.is_contact   = true
      c.row_position = 0
      c.type_of      = 0
    end
    ds3.funders.find_or_create_by!(name: "Illinois Research Board") do |f|
      f.grant = "IRB-2024-002"
    end

    ds3.datafiles.find_or_create_by!(binary_name: "data.csv") do |f|
      f.web_id       = "migrate3a"
      f.binary_size  = 256
      f.storage_root = "medusa"
      f.storage_key  = "migrate-test/data.csv"
      f.peek_type    = "code"
    end

    df3b = ds3.datafiles.find_or_create_by!(binary_name: "package.tar.gz") do |f|
      f.web_id       = "migrate3b"
      f.binary_size  = 2048
      f.storage_root = "medusa"
      f.storage_key  = "migrate-test/package.tar.gz"
      f.peek_type    = "notsupported"
    end

    tar_root = NestedItem.find_or_create_by!(datafile_id: df3b.id, item_name: "package", parent_id: nil) do |ni|
      ni.item_path    = "package/"
      ni.is_directory = true
      ni.media_type   = "inode/directory"
      ni.size         = 0
    end
    NestedItem.find_or_create_by!(datafile_id: df3b.id, item_name: "Makefile", parent_id: tar_root.id) do |ni|
      ni.item_path    = "package/Makefile"
      ni.is_directory = false
      ni.media_type   = "text/plain"
      ni.size         = 256
    end
    NestedItem.find_or_create_by!(datafile_id: df3b.id, item_name: "src", parent_id: tar_root.id) do |ni|
      ni.item_path    = "package/src/"
      ni.is_directory = true
      ni.media_type   = "inode/directory"
      ni.size         = 0
    end

    puts "Created dataset 3: #{ds3.key} (multi-file, #{NestedItem.where(datafile_id: df3b.id).count} nested items)"
    puts ""
    puts "Seeding complete. Export with:"
    puts "  bin/rails migration:legacy:export_test_bundle OUTPUT_ROOT=/tmp/migration_test_export"
    puts "  INCLUDE_TESTS=true bin/rails migration:legacy:export_bundle OUTPUT_ROOT=/tmp/migration_test_export"
  end

  desc "add seed binaries to bucket"
  task store_seed_datafiles: :environment do
    puts "adding seed binaries to bucket"
    transfer_manager = Aws::S3::TransferManager.new(client: Application.aws_client)

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
        transfer_manager.upload_file(file, bucket: root.bucket, key: key)
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