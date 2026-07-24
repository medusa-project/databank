require 'nokogiri'

namespace :experts do
  desc 'generate export doc'
  task :generate_doc => :environment do
    File.open(File.join(Rails.root, "public", "illinois_experts.xml"), 'w') do |f|
      f << Dataset.to_illinois_experts
    end
  end

  desc 'fetch demo export doc'
  task :fetch_demo_doc => :environment do
    demo_doc = Nokogiri::XML(open("https://demo.databank.illinois.edu/illinois_experts.xml"))
    File.open(File.join(Rails.root, "public", "illinois_experts_demo.xml"), 'w') do |f|
      f << demo_doc.to_xml
    end
  end

  desc 'explore persons'
  task :explore_persons => :environment do
    doc = IllinoisExpertsClient.person_xml_doc("netid@illinois.edu")

    start_date = doc.xpath("//period/startDate")
    puts "start_date: #{start_date}"

    org_uuids = doc.xpath("//organisationalUnit/@uuid")
    if org_uuids.empty?
      puts "org_uuids was empty"
    else
      org_uuids.each do |org_uuid|
        puts "org_uuid_class: #{org_uuid.class.name}"
        puts "org_uuid:"
        puts org_uuid.content
      end
    end
  end

  desc 'confirm current API person lookup; args: email_file, credential_source(current|production_ie), mode(dry|live)'
  task :confirm_current_api, [:email_file, :credential_source, :mode] => :environment do |_task, args|
    email_file = args[:email_file].presence
    credential_source = args[:credential_source].presence || 'current'
    mode = args[:mode].to_s.downcase
    dry_run = mode != 'live'

    abort('email_file is required') if email_file.blank?
    abort("email file not found: #{email_file}") unless File.exist?(email_file)

    raw_values = File.read(email_file).split(/[\s,;]+/)
    emails = raw_values.reject(&:blank?)
    abort("email file had no parseable values: #{email_file}") if emails.empty?

    endpoint_override = nil
    key_override = nil
    if credential_source == 'production_ie'
      config_path = Rails.root.join('config/credentials/production.yml.enc')
      key_path = Rails.root.join('config/credentials/production.key')

      abort("missing credentials file: #{config_path}") unless File.exist?(config_path)
      abort("missing key file: #{key_path}") unless File.exist?(key_path)

      encrypted_config = ActiveSupport::EncryptedConfiguration.new(
        config_path: config_path,
        key_path: key_path,
        env_key: 'RAILS_MASTER_KEY',
        raise_if_missing_key: true
      )
      ie_config = encrypted_config.config[:illinois_experts] || {}
      endpoint_override = ie_config[:endpoint]
      key_override = ie_config[:key]

      abort('production illinois_experts endpoint is missing') if endpoint_override.blank?
      abort('production illinois_experts key is missing') if key_override.blank?
    elsif credential_source != 'current'
      abort("invalid credential_source: #{credential_source} (expected current or production_ie)")
    end

    report = IllinoisExpertsClient.with_overrides(endpoint: endpoint_override, key: key_override) do
      IllinoisExpertsClient.confirm_persons_lookup(emails: emails, dry_run: dry_run)
    end

    puts 'Illinois Experts current API confirmation'
    puts "credential_source: #{credential_source}"
    puts "endpoint_host: #{report[:endpoint_host] || '(missing)'}"
    puts "key_present: #{report[:key_present]}"
    puts "requested_count: #{report[:requested_count]}"
    puts "internal_requested_count: #{report[:internal_requested_count]}"
    puts "skipped_non_internal_count: #{report[:skipped_non_internal_count]}"
    puts "dry_run: #{report[:dry_run]}"
    puts "email_file: #{email_file}"

    unless report[:dry_run]
      puts "found_count: #{report[:found_count]}"
      puts "missing_count: #{report[:missing_count]}"
      puts "with_org_uuid_count: #{report[:with_org_uuid_count]}"
      puts "with_start_date_count: #{report[:with_start_date_count]}"
      puts "elapsed_seconds: #{report[:elapsed_seconds]}"
    end
  end
end