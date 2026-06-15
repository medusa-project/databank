# frozen_string_literal: true

require "json"
require "digest"
require "fileutils"

module Migration; end
module Migration::Legacy; end

# Migration bundle export usage examples (legacy databank)
#
# Export all datasets (primary bundle):
#   bin/rails migration:legacy:export_bundle OUTPUT_ROOT=/tmp/databank_exports
#
# Export all cutover bundles into one root (each task creates timestamped subdir):
#   bin/rails migration:legacy:export_bundle OUTPUT_ROOT=/tmp/databank_exports
#   bin/rails migration:legacy:export_permissions_bundle OUTPUT_ROOT=/tmp/databank_exports
#   bin/rails migration:legacy:export_dataset_access_grants_bundle OUTPUT_ROOT=/tmp/databank_exports
#   bin/rails migration:legacy:export_guides_bundle OUTPUT_ROOT=/tmp/databank_exports
#   bin/rails migration:legacy:export_featured_researchers_bundle OUTPUT_ROOT=/tmp/databank_exports
#   bin/rails migration:legacy:export_medusa_ingests_bundle OUTPUT_ROOT=/tmp/databank_exports
#   bin/rails migration:legacy:export_download_metrics_bundle OUTPUT_ROOT=/tmp/databank_exports
#
# Common filters:
#   SINCE=2026-01-01T00:00:00Z UNTIL=2026-02-01T00:00:00Z
#   INCLUDE_TESTS=true (dataset and download metrics exports)
#   ACTIVE_ONLY=true (featured researcher export)
#
# Expected artifacts per bundle run:
#   <bundle>.ndjson
#   <bundle>.ndjson.sha256
#   manifest.json

class Migration::Legacy::ExportSerializer
  def initialize(dataset)
    @dataset = dataset
  end

  def as_json # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
    {
      key:                        dataset.key,
      title:                      dataset.title,
      identifier:                 dataset.identifier,
      publisher:                  dataset.publisher,
      publication_year:           dataset.publication_year,
      description:                dataset.description,
      license:                    dataset.license,
      corresponding_creator_name: dataset.corresponding_creator_name,
      depositor_name:             dataset.depositor_name,
      depositor_email:            dataset.depositor_email,
      owner_uid:                  owner_uid,
      subject:                    dataset.subject,
      keywords:                   dataset.keywords,
      publication_state:          dataset.publication_state,
      hold_state:                 dataset.hold_state,
      release_date:               dataset.release_date,
      embargo:                    dataset.embargo,
      is_test:                    dataset.is_test,
      is_import:                  dataset.is_import,
      tombstone_date:             dataset.tombstone_date,
      dataset_version:            dataset.dataset_version,
      created_at:                 dataset.created_at,
      updated_at:                 dataset.updated_at,
      creators:                   serialized_creators,
      contributors:               serialized_contributors,
      funders:                    serialized_funders,
      related_materials:          serialized_related_materials,
      datafiles:                  serialized_datafiles,
      notes:                      serialized_notes,
      token:                      serialized_token,
      url:                        dataset_json_url
    }
  end

  private

  attr_reader :dataset

  def owner_uid
    user = User.find_by(email: dataset.depositor_email)
    return user.uid if user&.uid.present?

    fallback = dataset.depositor_email.to_s.strip
    return "legacy:#{fallback}" if fallback.present?

    "legacy:dataset-#{dataset.id}"
  end

  def dataset_json_url
    "#{IDB_CONFIG[:root_url_text]}/datasets/#{dataset.key}.json"
  end

  def serialized_creators
    dataset.creators.order(:row_position, :id).map do |creator|
      {
        family_name:  creator.family_name,
        given_name:   creator.given_name,
        name:         creator.institution_name,
        email:        creator.email,
        identifier:   creator.identifier,
        is_contact:   creator.is_contact,
        row_position: creator.row_position,
        created_at:   creator.created_at,
        updated_at:   creator.updated_at
      }
    end
  end

  def serialized_contributors
    dataset.contributors.order(:row_position, :id).map do |contributor|
      {
        family_name:  contributor.family_name,
        given_name:   contributor.given_name,
        name:         contributor.institution_name,
        identifier:   contributor.identifier,
        row_position: contributor.row_position,
        created_at:   contributor.created_at,
        updated_at:   contributor.updated_at
      }
    end
  end

  def serialized_funders
    dataset.funders.order(:id).map do |funder|
      {
        name:              funder.name,
        identifier:        funder.identifier,
        identifier_scheme: funder.identifier_scheme,
        grant:             funder.grant,
        created_at:        funder.created_at,
        updated_at:        funder.updated_at
      }
    end
  end

  def serialized_related_materials
    dataset.related_materials.order(:id).map do |material|
      {
        material_type: material.material_type,
        availability:  material.availability,
        link:          material.link,
        uri:           material.uri,
        uri_type:      material.uri_type,
        citation:      material.citation,
        created_at:    material.created_at,
        updated_at:    material.updated_at
      }
    end
  end

  def serialized_datafiles
    dataset.datafiles.order(:id).map do |datafile|
      {
        web_id:       datafile.web_id,
        binary_name:  datafile.binary_name,
        binary_size:  datafile.binary_size,
        medusa_id:    datafile.medusa_id,
        storage_root: datafile.storage_root,
        storage_key:  datafile.storage_key,
        description:  datafile.description,
        created_at:   datafile.created_at,
        updated_at:   datafile.updated_at
      }
    end
  end

  def serialized_notes
    dataset.notes.order(:created_at, :id).map do |note|
      {
        body:       note.body,
        author:     note.author,
        created_at: note.created_at,
        updated_at: note.updated_at
      }
    end
  end

  def serialized_token
    token = Token.where(dataset_key: dataset.key).order(updated_at: :desc, id: :desc).first
    return nil if token.nil?

    {
      identifier: token.identifier,
      expires: token.expires,
      created_at: token.created_at,
      updated_at: token.updated_at
    }
  end
end

class Migration::Legacy::GuideExportSerializer
  def initialize(record)
    @record = record
  end

  def as_json
    {
      type: record.class.name,
      attributes: serialized_attributes
    }
  end

  private

  attr_reader :record

  def serialized_attributes
    base = {
      id: record.id,
      anchor: record.anchor,
      label: record.label,
      ordinal: record.ordinal,
      public: record.public,
      heading: record.heading,
      body: record.body,
      created_at: record.created_at,
      updated_at: record.updated_at
    }

    case record
    when Guide::Item
      base.merge(section_id: record.section_id)
    when Guide::Subitem
      base.merge(item_id: record.item_id)
    else
      base
    end
  end
end

class Migration::Legacy::FeaturedResearcherExportSerializer
  def initialize(featured_researcher)
    @featured_researcher = featured_researcher
  end

  def as_json
    {
      type: "FeaturedResearcher",
      attributes: {
        id: featured_researcher.id,
        name: featured_researcher.name,
        question: featured_researcher.question,
        testimonial: featured_researcher.testimonial,
        bio: featured_researcher.bio,
        photo_url: featured_researcher.photo_url,
        dataset_url: featured_researcher.dataset_url,
        article_url: featured_researcher.article_url,
        is_active: featured_researcher.is_active,
        created_at: featured_researcher.created_at,
        updated_at: featured_researcher.updated_at
      }
    }
  end

  private

  attr_reader :featured_researcher
end

class Migration::Legacy::PermissionExportSerializer
  def initialize(type:, email:, user_provider:, user_uid:)
    @type = type
    @email = email
    @user_provider = user_provider
    @user_uid = user_uid
  end

  def as_json
    {
      type: type,
      attributes: {
        email: email,
        source_provider: user_provider,
        source_uid: user_uid
      }
    }
  end

  private

  attr_reader :type, :email, :user_provider, :user_uid
end

class Migration::Legacy::DatasetAccessGrantExportSerializer
  def initialize(dataset_key:, email:, access_level:, user_provider:, user_uid:, legacy_resource_id:, abilities:)
    @dataset_key = dataset_key
    @email = email
    @access_level = access_level
    @user_provider = user_provider
    @user_uid = user_uid
    @legacy_resource_id = legacy_resource_id
    @abilities = abilities
  end

  def as_json
    {
      type: "DatasetAccessGrant",
      attributes: {
        dataset_key: dataset_key,
        email: email,
        access_level: access_level,
        source_provider: user_provider,
        source_uid: user_uid,
        legacy_resource_id: legacy_resource_id,
        abilities: abilities
      }
    }
  end

  private

  attr_reader :dataset_key, :email, :access_level, :user_provider, :user_uid, :legacy_resource_id, :abilities
end

class Migration::Legacy::MedusaIngestExportSerializer
  def initialize(medusa_ingest)
    @medusa_ingest = medusa_ingest
  end

  def as_json
    {
      type: "MedusaIngest",
      attributes: {
        legacy_id: medusa_ingest.id,
        dataset_key: dataset_key,
        idb_class: medusa_ingest.idb_class,
        idb_identifier: medusa_ingest.idb_identifier,
        staging_path: medusa_ingest.staging_path,
        staging_key: medusa_ingest.staging_key,
        target_key: medusa_ingest.target_key,
        medusa_path: medusa_ingest.medusa_path,
        medusa_uuid: medusa_ingest.medusa_uuid,
        medusa_dataset_dir: medusa_ingest.medusa_dataset_dir,
        request_status: medusa_ingest.request_status,
        response_time: medusa_ingest.response_time,
        error_text: medusa_ingest.error_text,
        created_at: medusa_ingest.created_at,
        updated_at: medusa_ingest.updated_at
      }
    }
  end

  private

  attr_reader :medusa_ingest

  def dataset_key
    return medusa_ingest.idb_identifier if medusa_ingest.idb_class != "datafile"

    datafile = Datafile.includes(:dataset).find_by(web_id: medusa_ingest.idb_identifier)
    datafile&.dataset&.key
  end
end

class Migration::Legacy::DatasetDownloadTallyExportSerializer
  def initialize(dataset_download_tally)
    @dataset_download_tally = dataset_download_tally
  end

  def as_json
    {
      type: "DatasetDownloadTally",
      attributes: {
        legacy_id: dataset_download_tally.id,
        dataset_key: dataset_download_tally.dataset_key,
        doi: dataset_download_tally.doi,
        download_date: dataset_download_tally.download_date,
        tally: dataset_download_tally.tally,
        created_at: dataset_download_tally.created_at,
        updated_at: dataset_download_tally.updated_at
      }
    }
  end

  private

  attr_reader :dataset_download_tally
end

class Migration::Legacy::FileDownloadTallyExportSerializer
  def initialize(file_download_tally)
    @file_download_tally = file_download_tally
  end

  def as_json
    {
      type: "FileDownloadTally",
      attributes: {
        legacy_id: file_download_tally.id,
        file_web_id: file_download_tally.file_web_id,
        filename: file_download_tally.filename,
        dataset_key: file_download_tally.dataset_key,
        doi: file_download_tally.doi,
        download_date: file_download_tally.download_date,
        tally: file_download_tally.tally,
        created_at: file_download_tally.created_at,
        updated_at: file_download_tally.updated_at
      }
    }
  end

  private

  attr_reader :file_download_tally
end

class Migration::Legacy::DayFileDownloadExportSerializer
  def initialize(day_file_download)
    @day_file_download = day_file_download
  end

  def as_json
    {
      type: "DayFileDownload",
      attributes: {
        legacy_id: day_file_download.id,
        ip_address: day_file_download.ip_address,
        file_web_id: day_file_download.file_web_id,
        filename: day_file_download.filename,
        dataset_key: day_file_download.dataset_key,
        doi: day_file_download.doi,
        download_date: day_file_download.download_date,
        created_at: day_file_download.created_at,
        updated_at: day_file_download.updated_at
      }
    }
  end

  private

  attr_reader :day_file_download
end

namespace :migration do # rubocop:disable Metrics/BlockLength
  namespace :legacy do # rubocop:disable Metrics/BlockLength
    desc "Export legacy datasets to NDJSON with SHA256 artifacts"
    task export_bundle: :environment do # rubocop:disable Metrics/BlockLength
      output_root = ENV.fetch("OUTPUT_ROOT", Rails.root.join("tmp/migration_exports").to_s)
      include_tests = ENV.fetch("INCLUDE_TESTS", "false").casecmp("true").zero?
      since_raw = ENV["SINCE"]
      until_raw = ENV["UNTIL"]

      since_time = since_raw.present? ? Time.zone.parse(since_raw) : nil
      until_time = until_raw.present? ? Time.zone.parse(until_raw) : nil

      timestamp = Time.current.utc.strftime("%Y%m%dT%H%M%SZ")
      run_dir = File.join(output_root, "dataset_#{timestamp}")
      FileUtils.mkdir_p(run_dir)

      bundle_file = "legacy_datasets.ndjson"
      bundle_path = File.join(run_dir, bundle_file)
      checksum_path = "#{bundle_path}.sha256"
      manifest_path = File.join(run_dir, "manifest.json")

      scope = Dataset.includes(:creators, :contributors, :funders, :related_materials, :datafiles, :notes)
      scope = scope.where(is_test: false) unless include_tests
      scope = scope.where("updated_at >= ?", since_time) if since_time
      scope = scope.where("updated_at < ?", until_time) if until_time
      scope = scope.order(:id)

      digest = Digest::SHA256.new
      count = 0

      File.open(bundle_path, "w") do |file|
        scope.find_each(batch_size: 200) do |dataset|
          record = Migration::Legacy::ExportSerializer.new(dataset).as_json
          line = JSON.generate(record)
          file.write(line)
          file.write("\n")
          digest.update(line)
          digest.update("\n")
          count += 1
        end
      end

      checksum = digest.hexdigest
      File.write(checksum_path, "#{checksum}  #{bundle_file}\n")

      manifest = {
        generated_at:  Time.current.utc.iso8601,
        bundle_file:   bundle_file,
        record_count:  count,
        sha256:        checksum,
        include_tests: include_tests,
        since:         since_time&.iso8601,
        until:         until_time&.iso8601
      }
      File.write(manifest_path, JSON.pretty_generate(manifest))

      puts "Bundle: #{bundle_path}"
      puts "Checksum: #{checksum_path}"
      puts "Manifest: #{manifest_path}"
      puts "Record count: #{count}"
    end

    desc "Export legacy guides to NDJSON with SHA256 artifacts"
    task export_guides_bundle: :environment do # rubocop:disable Metrics/BlockLength
      output_root = ENV.fetch("OUTPUT_ROOT", Rails.root.join("tmp/migration_exports_guides").to_s)

      timestamp = Time.current.utc.strftime("%Y%m%dT%H%M%SZ")
      run_dir = File.join(output_root, "guide_#{timestamp}")
      FileUtils.mkdir_p(run_dir)

      bundle_file = "legacy_guides.ndjson"
      bundle_path = File.join(run_dir, bundle_file)
      checksum_path = "#{bundle_path}.sha256"
      manifest_path = File.join(run_dir, "manifest.json")

      digest = Digest::SHA256.new
      record_count = 0
      section_count = 0
      item_count = 0
      subitem_count = 0

      scope = Guide::Section.includes(guide_items: :guide_subitems)

      File.open(bundle_path, "w") do |file|
        sections = scope.to_a.sort_by { |section| [ section.ordinal || Float::INFINITY, section.id ] }

        sections.each do |section|
          line = JSON.generate(Migration::Legacy::GuideExportSerializer.new(section).as_json)
          file.write(line)
          file.write("\n")
          digest.update(line)
          digest.update("\n")
          record_count += 1
          section_count += 1

          items = section.guide_items.to_a.sort_by { |item| [ item.ordinal || Float::INFINITY, item.id ] }
          items.each do |item|
            line = JSON.generate(Migration::Legacy::GuideExportSerializer.new(item).as_json)
            file.write(line)
            file.write("\n")
            digest.update(line)
            digest.update("\n")
            record_count += 1
            item_count += 1

            subitems = item.guide_subitems.to_a.sort_by { |subitem| [ subitem.ordinal || Float::INFINITY, subitem.id ] }
            subitems.each do |subitem|
              line = JSON.generate(Migration::Legacy::GuideExportSerializer.new(subitem).as_json)
              file.write(line)
              file.write("\n")
              digest.update(line)
              digest.update("\n")
              record_count += 1
              subitem_count += 1
            end
          end
        end
      end

      checksum = digest.hexdigest
      File.write(checksum_path, "#{checksum}  #{bundle_file}\n")

      manifest = {
        generated_at: Time.current.utc.iso8601,
        bundle_file: bundle_file,
        record_count: record_count,
        counts: {
          "Guide::Section" => section_count,
          "Guide::Item" => item_count,
          "Guide::Subitem" => subitem_count
        },
        sha256: checksum,
        format_version: 1
      }
      File.write(manifest_path, JSON.pretty_generate(manifest))

      puts "Bundle: #{bundle_path}"
      puts "Checksum: #{checksum_path}"
      puts "Manifest: #{manifest_path}"
      puts "Record count: #{record_count}"
      puts "Guide::Section: #{section_count}"
      puts "Guide::Item: #{item_count}"
      puts "Guide::Subitem: #{subitem_count}"
    end

    desc "Export legacy researcher spotlights to NDJSON with SHA256 artifacts"
    task export_featured_researchers_bundle: :environment do
      output_root = ENV.fetch("OUTPUT_ROOT", Rails.root.join("tmp/migration_exports_featured_researchers").to_s)
      active_only = ENV.fetch("ACTIVE_ONLY", "false").casecmp("true").zero?
      since_raw = ENV["SINCE"]
      until_raw = ENV["UNTIL"]

      since_time = since_raw.present? ? Time.zone.parse(since_raw) : nil
      until_time = until_raw.present? ? Time.zone.parse(until_raw) : nil

      timestamp = Time.current.utc.strftime("%Y%m%dT%H%M%SZ")
      run_dir = File.join(output_root, "spotlight_#{timestamp}")
      FileUtils.mkdir_p(run_dir)

      bundle_file = "legacy_featured_researchers.ndjson"
      bundle_path = File.join(run_dir, bundle_file)
      checksum_path = "#{bundle_path}.sha256"
      manifest_path = File.join(run_dir, "manifest.json")

      scope = FeaturedResearcher.order(:id)
      scope = scope.where(is_active: true) if active_only
      scope = scope.where("updated_at >= ?", since_time) if since_time
      scope = scope.where("updated_at < ?", until_time) if until_time

      digest = Digest::SHA256.new
      count = 0

      File.open(bundle_path, "w") do |file|
        scope.find_each(batch_size: 200) do |featured_researcher|
          line = JSON.generate(Migration::Legacy::FeaturedResearcherExportSerializer.new(featured_researcher).as_json)
          file.write(line)
          file.write("\n")
          digest.update(line)
          digest.update("\n")
          count += 1
        end
      end

      checksum = digest.hexdigest
      File.write(checksum_path, "#{checksum}  #{bundle_file}\n")

      manifest = {
        generated_at: Time.current.utc.iso8601,
        bundle_file: bundle_file,
        record_count: count,
        counts: {
          "FeaturedResearcher" => count
        },
        sha256: checksum,
        active_only: active_only,
        since: since_time&.iso8601,
        until: until_time&.iso8601,
        format_version: 1
      }
      File.write(manifest_path, JSON.pretty_generate(manifest))

      puts "Bundle: #{bundle_path}"
      puts "Checksum: #{checksum_path}"
      puts "Manifest: #{manifest_path}"
      puts "Record count: #{count}"
    end

    desc "Export legacy curator/deposit-exception permissions to NDJSON with SHA256 artifacts"
    task export_permissions_bundle: :environment do
      output_root = ENV.fetch("OUTPUT_ROOT", Rails.root.join("tmp/migration_exports_permissions").to_s)

      timestamp = Time.current.utc.strftime("%Y%m%dT%H%M%SZ")
      run_dir = File.join(output_root, "permissions_#{timestamp}")
      FileUtils.mkdir_p(run_dir)

      bundle_file = "legacy_permissions.ndjson"
      bundle_path = File.join(run_dir, bundle_file)
      checksum_path = "#{bundle_path}.sha256"
      manifest_path = File.join(run_dir, "manifest.json")

      normalize_email = lambda do |value|
        raw = value.to_s.strip.downcase
        return nil if raw.blank?

        return raw if raw.include?("@")

        "#{raw}@illinois.edu"
      end

      resolve_email = lambda do |ability|
        user = User.find_by(provider: ability.user_provider, uid: ability.user_uid)
        candidate = user&.email.presence || ability.user_uid
        normalized = normalize_email.call(candidate)
        return nil unless normalized =~ URI::MailTo::EMAIL_REGEXP

        normalized
      end

      records = []
      skipped = 0

      curator_rows = UserAbility.where(resource_type: "Databank", resource_id: nil, ability: "manage").order(:id)
      curator_rows.find_each do |ability|
        email = resolve_email.call(ability)
        if email.blank?
          skipped += 1
          next
        end

        records << Migration::Legacy::PermissionExportSerializer.new(
          type: "ManagedCurator",
          email: email,
          user_provider: ability.user_provider,
          user_uid: ability.user_uid
        ).as_json
      end

      deposit_exception_rows = UserAbility.where(resource_type: "Dataset", resource_id: nil, ability: "create").order(:id)
      deposit_exception_rows.find_each do |ability|
        email = resolve_email.call(ability)
        if email.blank?
          skipped += 1
          next
        end

        records << Migration::Legacy::PermissionExportSerializer.new(
          type: "ManagedDepositException",
          email: email,
          user_provider: ability.user_provider,
          user_uid: ability.user_uid
        ).as_json
      end

      unique_records = records.uniq { |record| [ record[:type], record.dig(:attributes, :email) ] }
      counts = unique_records.group_by { |record| record[:type] }.transform_values(&:count)

      digest = Digest::SHA256.new
      File.open(bundle_path, "w") do |file|
        unique_records.each do |record|
          line = JSON.generate(record)
          file.write(line)
          file.write("\n")
          digest.update(line)
          digest.update("\n")
        end
      end

      checksum = digest.hexdigest
      File.write(checksum_path, "#{checksum}  #{bundle_file}\n")

      manifest = {
        generated_at: Time.current.utc.iso8601,
        bundle_file: bundle_file,
        record_count: unique_records.count,
        counts: counts,
        skipped_invalid: skipped,
        sha256: checksum,
        format_version: 1
      }
      File.write(manifest_path, JSON.pretty_generate(manifest))

      puts "Bundle: #{bundle_path}"
      puts "Checksum: #{checksum_path}"
      puts "Manifest: #{manifest_path}"
      puts "Record count: #{unique_records.count}"
      puts "ManagedCurator: #{counts.fetch('ManagedCurator', 0)}"
      puts "ManagedDepositException: #{counts.fetch('ManagedDepositException', 0)}"
      puts "Skipped invalid: #{skipped}"
    end

    desc "Export legacy dataset access grants to NDJSON with SHA256 artifacts"
    task export_dataset_access_grants_bundle: :environment do
      output_root = ENV.fetch("OUTPUT_ROOT", Rails.root.join("tmp/migration_exports_dataset_access_grants").to_s)

      timestamp = Time.current.utc.strftime("%Y%m%dT%H%M%SZ")
      run_dir = File.join(output_root, "dataset_access_grants_#{timestamp}")
      FileUtils.mkdir_p(run_dir)

      bundle_file = "legacy_dataset_access_grants.ndjson"
      bundle_path = File.join(run_dir, bundle_file)
      checksum_path = "#{bundle_path}.sha256"
      manifest_path = File.join(run_dir, "manifest.json")

      normalize_email = lambda do |value|
        raw = value.to_s.strip.downcase
        return nil if raw.blank?

        return raw if raw.include?("@")

        "#{raw}@illinois.edu"
      end

      resolve_email = lambda do |ability|
        user = User.find_by(provider: ability.user_provider, uid: ability.user_uid)
        candidate = user&.email.presence || ability.user_uid
        normalized = normalize_email.call(candidate)
        return nil unless normalized =~ URI::MailTo::EMAIL_REGEXP

        normalized
      end

      grouped_rows = UserAbility
        .where(resource_type: "Dataset")
        .where.not(resource_id: nil)
        .where(ability: %w[read view_files update])
        .order(:resource_id, :user_provider, :user_uid, :ability)
        .group_by { |ability| [ ability.resource_id, ability.user_provider, ability.user_uid ] }

      records = []
      skipped = 0

      grouped_rows.each_value do |abilities_for_user|
        exemplar = abilities_for_user.first
        dataset = Dataset.find_by(id: exemplar.resource_id)
        if dataset.nil? || dataset.key.blank?
          skipped += 1
          next
        end

        email = resolve_email.call(exemplar)
        if email.blank?
          skipped += 1
          next
        end

        ability_names = abilities_for_user.map { |ability| ability.ability.to_s }.uniq.sort
        access_level = ability_names.include?("update") ? "editor" : "viewer"

        records << Migration::Legacy::DatasetAccessGrantExportSerializer.new(
          dataset_key: dataset.key,
          email: email,
          access_level: access_level,
          user_provider: exemplar.user_provider,
          user_uid: exemplar.user_uid,
          legacy_resource_id: exemplar.resource_id,
          abilities: ability_names
        ).as_json
      end

      unique_records = records.uniq { |record| [ record.dig(:attributes, :dataset_key), record.dig(:attributes, :email) ] }
      counts = unique_records.group_by { |record| record.dig(:attributes, :access_level) }.transform_values(&:count)

      digest = Digest::SHA256.new
      File.open(bundle_path, "w") do |file|
        unique_records.each do |record|
          line = JSON.generate(record)
          file.write(line)
          file.write("\n")
          digest.update(line)
          digest.update("\n")
        end
      end

      checksum = digest.hexdigest
      File.write(checksum_path, "#{checksum}  #{bundle_file}\n")

      manifest = {
        generated_at: Time.current.utc.iso8601,
        bundle_file: bundle_file,
        record_count: unique_records.count,
        counts: {
          "DatasetAccessGrant" => unique_records.count,
          "viewer" => counts.fetch("viewer", 0),
          "editor" => counts.fetch("editor", 0)
        },
        skipped_invalid: skipped,
        sha256: checksum,
        format_version: 1
      }
      File.write(manifest_path, JSON.pretty_generate(manifest))

      puts "Bundle: #{bundle_path}"
      puts "Checksum: #{checksum_path}"
      puts "Manifest: #{manifest_path}"
      puts "Record count: #{unique_records.count}"
      puts "Viewer grants: #{counts.fetch('viewer', 0)}"
      puts "Editor grants: #{counts.fetch('editor', 0)}"
      puts "Skipped invalid: #{skipped}"
    end

    desc "Export legacy Medusa ingests to NDJSON with SHA256 artifacts"
    task export_medusa_ingests_bundle: :environment do
      output_root = ENV.fetch("OUTPUT_ROOT", Rails.root.join("tmp/migration_exports_medusa_ingests").to_s)
      since_raw = ENV["SINCE"]
      until_raw = ENV["UNTIL"]

      since_time = since_raw.present? ? Time.zone.parse(since_raw) : nil
      until_time = until_raw.present? ? Time.zone.parse(until_raw) : nil

      timestamp = Time.current.utc.strftime("%Y%m%dT%H%M%SZ")
      run_dir = File.join(output_root, "medusa_ingests_#{timestamp}")
      FileUtils.mkdir_p(run_dir)

      bundle_file = "legacy_medusa_ingests.ndjson"
      bundle_path = File.join(run_dir, bundle_file)
      checksum_path = "#{bundle_path}.sha256"
      manifest_path = File.join(run_dir, "manifest.json")

      scope = MedusaIngest.order(:id)
      scope = scope.where("updated_at >= ?", since_time) if since_time
      scope = scope.where("updated_at < ?", until_time) if until_time

      records = []
      skipped = 0

      scope.find_each(batch_size: 500) do |medusa_ingest|
        record = Migration::Legacy::MedusaIngestExportSerializer.new(medusa_ingest).as_json
        if record.dig(:attributes, :dataset_key).blank?
          skipped += 1
          next
        end

        records << record
      end

      counts = records.group_by { |record| record.dig(:attributes, :request_status).to_s.presence || "pending" }.transform_values(&:count)

      digest = Digest::SHA256.new
      File.open(bundle_path, "w") do |file|
        records.each do |record|
          line = JSON.generate(record)
          file.write(line)
          file.write("\n")
          digest.update(line)
          digest.update("\n")
        end
      end

      checksum = digest.hexdigest
      File.write(checksum_path, "#{checksum}  #{bundle_file}\n")

      manifest = {
        generated_at: Time.current.utc.iso8601,
        bundle_file: bundle_file,
        record_count: records.count,
        counts: {
          "MedusaIngest" => records.count
        }.merge(counts),
        skipped_invalid: skipped,
        sha256: checksum,
        format_version: 1
      }
      File.write(manifest_path, JSON.pretty_generate(manifest))

      puts "Bundle: #{bundle_path}"
      puts "Checksum: #{checksum_path}"
      puts "Manifest: #{manifest_path}"
      puts "Record count: #{records.count}"
      puts "Skipped invalid: #{skipped}"
      counts.keys.sort.each do |status|
        puts "request_status #{status}: #{counts.fetch(status, 0)}"
      end
    end

    desc "Export legacy download metrics records to NDJSON with SHA256 artifacts"
    task export_download_metrics_bundle: :environment do
      output_root = ENV.fetch("OUTPUT_ROOT", Rails.root.join("tmp/migration_exports_download_metrics").to_s)
      include_tests = ENV.fetch("INCLUDE_TESTS", "false").casecmp("true").zero?
      since_raw = ENV["SINCE"]
      until_raw = ENV["UNTIL"]

      since_time = since_raw.present? ? Time.zone.parse(since_raw) : nil
      until_time = until_raw.present? ? Time.zone.parse(until_raw) : nil

      timestamp = Time.current.utc.strftime("%Y%m%dT%H%M%SZ")
      run_dir = File.join(output_root, "download_metrics_#{timestamp}")
      FileUtils.mkdir_p(run_dir)

      bundle_file = "legacy_download_metrics.ndjson"
      bundle_path = File.join(run_dir, bundle_file)
      checksum_path = "#{bundle_path}.sha256"
      manifest_path = File.join(run_dir, "manifest.json")

      test_dataset_keys = include_tests ? [] : Dataset.where(is_test: true).pluck(:key)

      dataset_scope = DatasetDownloadTally.order(:id)
      file_scope = FileDownloadTally.order(:id)
      day_scope = DayFileDownload.order(:id)

      unless include_tests
        dataset_scope = dataset_scope.where.not(dataset_key: test_dataset_keys)
        file_scope = file_scope.where.not(dataset_key: test_dataset_keys)
        day_scope = day_scope.where.not(dataset_key: test_dataset_keys)
      end

      if since_time
        dataset_scope = dataset_scope.where("updated_at >= ?", since_time)
        file_scope = file_scope.where("updated_at >= ?", since_time)
        day_scope = day_scope.where("updated_at >= ?", since_time)
      end

      if until_time
        dataset_scope = dataset_scope.where("updated_at < ?", until_time)
        file_scope = file_scope.where("updated_at < ?", until_time)
        day_scope = day_scope.where("updated_at < ?", until_time)
      end

      digest = Digest::SHA256.new
      counts = Hash.new(0)
      record_count = 0

      File.open(bundle_path, "w") do |file|
        dataset_scope.find_each(batch_size: 1000) do |row|
          line = JSON.generate(Migration::Legacy::DatasetDownloadTallyExportSerializer.new(row).as_json)
          file.write(line)
          file.write("\n")
          digest.update(line)
          digest.update("\n")
          counts["DatasetDownloadTally"] += 1
          record_count += 1
        end

        file_scope.find_each(batch_size: 1000) do |row|
          line = JSON.generate(Migration::Legacy::FileDownloadTallyExportSerializer.new(row).as_json)
          file.write(line)
          file.write("\n")
          digest.update(line)
          digest.update("\n")
          counts["FileDownloadTally"] += 1
          record_count += 1
        end

        day_scope.find_each(batch_size: 1000) do |row|
          line = JSON.generate(Migration::Legacy::DayFileDownloadExportSerializer.new(row).as_json)
          file.write(line)
          file.write("\n")
          digest.update(line)
          digest.update("\n")
          counts["DayFileDownload"] += 1
          record_count += 1
        end
      end

      checksum = digest.hexdigest
      File.write(checksum_path, "#{checksum}  #{bundle_file}\n")

      manifest = {
        generated_at: Time.current.utc.iso8601,
        bundle_file: bundle_file,
        record_count: record_count,
        counts: {
          "DatasetDownloadTally" => counts.fetch("DatasetDownloadTally", 0),
          "FileDownloadTally" => counts.fetch("FileDownloadTally", 0),
          "DayFileDownload" => counts.fetch("DayFileDownload", 0)
        },
        sha256: checksum,
        include_tests: include_tests,
        since: since_time&.iso8601,
        until: until_time&.iso8601,
        format_version: 1
      }
      File.write(manifest_path, JSON.pretty_generate(manifest))

      puts "Bundle: #{bundle_path}"
      puts "Checksum: #{checksum_path}"
      puts "Manifest: #{manifest_path}"
      puts "Record count: #{record_count}"
      puts "DatasetDownloadTally records: #{counts.fetch('DatasetDownloadTally', 0)}"
      puts "FileDownloadTally records: #{counts.fetch('FileDownloadTally', 0)}"
      puts "DayFileDownload records: #{counts.fetch('DayFileDownload', 0)}"
    end
  end
end
