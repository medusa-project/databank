# frozen_string_literal: true

require "json"
require "digest"
require "fileutils"

module Migration; end
module Migration::Legacy; end

# Migration bundle export usage examples (legacy databank)
#
# Export all bundles at once into one root (recommended):
#   RAILS_ENV=demo bin/rails migration:legacy:export_all OUTPUT_ROOT=/tmp/databank_exports
#
# Or export individually:
#   RAILS_ENV=demo bin/rails migration:legacy:export_users_bundle OUTPUT_ROOT=/tmp/databank_exports
#   RAILS_ENV=demo bin/rails migration:legacy:export_bundle OUTPUT_ROOT=/tmp/databank_exports (exports datasets with nested_items in flat NDJSON format)
#   RAILS_ENV=demo bin/rails migration:legacy:export_permissions_bundle OUTPUT_ROOT=/tmp/databank_exports
#   RAILS_ENV=demo bin/rails migration:legacy:export_dataset_access_grants_bundle OUTPUT_ROOT=/tmp/databank_exports
#   RAILS_ENV=demo bin/rails migration:legacy:export_guides_bundle OUTPUT_ROOT=/tmp/databank_exports
#   RAILS_ENV=demo bin/rails migration:legacy:export_featured_researchers_bundle OUTPUT_ROOT=/tmp/databank_exports
#   RAILS_ENV=demo bin/rails migration:legacy:export_medusa_ingests_bundle OUTPUT_ROOT=/tmp/databank_exports
#   RAILS_ENV=demo bin/rails migration:legacy:export_download_metrics_bundle OUTPUT_ROOT=/tmp/databank_exports
#   RAILS_ENV=demo bin/rails migration:legacy:export_audits_bundle OUTPUT_ROOT=/tmp/databank_exports
#
# Individual exports useful for testing, re-running failed bundles, or selective metadata migration
#
# Common filters (applied before running export commands):
#   SINCE=2026-01-01T00:00:00Z UNTIL=2026-02-01T00:00:00Z
#   INCLUDE_TESTS=true (dataset and download metrics exports)
#   ACTIVE_ONLY=true (featured researcher export)
#
# Dataset exports now use flat NDJSON format with separate records for datasets, datafiles, and nested_items.
# Nested items are extracted from archive content hierarchy:
#   - ZIP files (bsdiff, bzip2, gzip, xz formats)
#   - TAR archives and compressed variants
#   - RAR and 7z archives
#   Nested items preserve parent-child relationships using item_id/parent_item_id references (format: "ni-{id}").
#
# Flat format benefits:
#   - Memory-efficient streaming import (no large nested JSON trees)
#   - Batch processing of records
#   - Easier relationship reconstruction
#   - Suitable for very large datasets with thousands of nested items
#
# Each export task creates a timestamped subdirectory with:
#   <bundle>.ndjson (NDJSON records, one per line, memory-efficient for large exports)
#   <bundle>.ndjson.sha256 (SHA256 checksum for integrity verification)
#   manifest.json (metadata about the export including record count and format_version: 2 for flat format)

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
      nested_updated_at:          dataset.nested_updated_at,
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
        identifier_scheme: creator.identifier_scheme,
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
        identifier_scheme: contributor.identifier_scheme,
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
      relation_types =
        if material.respond_to?(:relationship_arr)
          material.relationship_arr
        else
          material.datacite_list.to_s.split(",").map(&:strip).reject(&:blank?)
        end

      {
        material_type: material.material_type,
        selected_type: material.selected_type,
        availability:  material.availability,
        link:          material.link,
        uri:           material.uri,
        uri_type:      material.uri_type,
        citation:      material.citation,
        note:          material.note,
        datacite_list: relation_types.join(","),
        relation_types: relation_types,
        relation_type: relation_types.first,
        created_at:    material.created_at,
        updated_at:    material.updated_at
      }
    end
  end

  def serialized_datafiles
    dataset.datafiles.order(:id).map do |datafile|
      # Pre-load all nested items in one query instead of recursively querying
      nested_items_by_parent = datafile.nested_items.order(:id).group_by(&:parent_id)
      
      {
        web_id:       datafile.web_id,
        binary_name:  datafile.binary_name,
        binary_size:  datafile.binary_size,
        medusa_id:    datafile.medusa_id,
        storage_root: datafile.storage_root,
        storage_key:  datafile.storage_key,
        description:  datafile.description,
        peek_type:    datafile.peek_type,
        peek_text:    datafile.peek_text,
        nested_items: build_nested_items_tree(nil, nested_items_by_parent),
        created_at:   datafile.created_at,
        updated_at:   datafile.updated_at
      }
    end
  end

  def build_nested_items_tree(parent_id, nested_items_by_parent)
    (nested_items_by_parent[parent_id] || []).map do |nested_item|
      {
        item_name:    nested_item.item_name,
        media_type:   nested_item.media_type,
        size:         nested_item.size,
        item_path:    nested_item.item_path,
        is_directory: nested_item.is_directory,
        children:     build_nested_items_tree(nested_item.id, nested_items_by_parent),
        created_at:   nested_item.created_at,
        updated_at:   nested_item.updated_at
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

class Migration::Legacy::AuditExportSerializer
  AUDITABLE_TYPES = [ "Dataset", "Creator", "Contributor", "Funder", "RelatedMaterial" ].freeze

  def initialize(audit:, dataset:)
    @audit = audit
    @dataset = dataset
  end

  def as_json
    {
      type: "Audit",
      attributes: {
        legacy_audit_id: audit.id,
        dataset_key: dataset.key,
        action: audit.action,
        version: audit.version,
        comment: audit.comment,
        remote_address: audit.remote_address,
        request_uuid: audit.request_uuid,
        created_at: audit.created_at,
        audited_changes: audit.audited_changes,
        username: audit.username,
        user_type: audit.user_type,
        legacy_user_id: audit.user_id,
        user_identity: serialized_user_identity,
        auditable: serialized_reference(type: audit.auditable_type, legacy_id: audit.auditable_id, record: audit.auditable),
        associated: serialized_reference(type: audit.associated_type, legacy_id: audit.associated_id, record: audit.associated)
      }
    }
  end

  private

  attr_reader :audit, :dataset

  def serialized_user_identity
    return nil unless audit.user_id.present?

    user = User.find_by(id: audit.user_id)
    return nil if user.nil?

    {
      provider: user.provider,
      uid: user.uid,
      email: user.email
    }
  end

  def serialized_reference(type:, legacy_id:, record:)
    return nil if type.blank? && legacy_id.blank?

    {
      type: type,
      legacy_id: legacy_id,
      locator: locator_for(type: type, record: record)
    }
  end

  def locator_for(type:, record:)
    case type
    when "Dataset"
      {
        key: dataset.key
      }
    when "Creator", "Contributor"
      {
        row_position: attribute_value(record: record, key: "row_position"),
        given_name: attribute_value(record: record, key: "given_name"),
        family_name: attribute_value(record: record, key: "family_name"),
        institution_name: attribute_value(record: record, key: "institution_name", fallback_keys: [ "name" ]),
        name: normalized_name(record: record)
      }.compact
    when "Funder"
      {
        name: attribute_value(record: record, key: "name"),
        identifier: attribute_value(record: record, key: "identifier"),
        grant: attribute_value(record: record, key: "grant", fallback_keys: [ "award_number" ])
      }.compact
    when "RelatedMaterial"
      {
        uri: attribute_value(record: record, key: "uri"),
        citation: attribute_value(record: record, key: "citation"),
        link: attribute_value(record: record, key: "link"),
        material_type: attribute_value(record: record, key: "material_type"),
        title: normalized_related_material_title(record: record)
      }.compact
    else
      {}
    end
  end

  def normalized_name(record:)
    institution_name = attribute_value(record: record, key: "institution_name", fallback_keys: [ "name" ])
    return institution_name if institution_name.present?

    [
      attribute_value(record: record, key: "given_name"),
      attribute_value(record: record, key: "family_name")
    ].compact.join(" ").strip.presence
  end

  def normalized_related_material_title(record:)
    [
      attribute_value(record: record, key: "citation"),
      attribute_value(record: record, key: "link"),
      attribute_value(record: record, key: "material_type")
    ].compact.find(&:present?)
  end

  def attribute_value(record:, key:, fallback_keys: [])
    value = nil
    if record.respond_to?(key)
      value = record.public_send(key)
    else
      changed_value = key_from_changes(key)
      value = changed_value if changed_value.present?
    end

    return value if value.present?

    fallback_keys.each do |fallback_key|
      fallback_value = nil
      if record.respond_to?(fallback_key)
        fallback_value = record.public_send(fallback_key)
      else
        fallback_value = key_from_changes(fallback_key)
      end
      return fallback_value if fallback_value.present?
    end

    nil
  end

  def key_from_changes(key)
    return nil unless audit.audited_changes.is_a?(Hash)

    raw_value = audit.audited_changes[key] || audit.audited_changes[key.to_sym]
    return raw_value unless raw_value.is_a?(Array)

    case audit.action.to_s
    when "destroy"
      raw_value.first
    else
      raw_value.last
    end
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

class Migration::Legacy::UserExportSerializer
  ROLE_MAP = {
    Databank::UserRole::ADMIN => "curator",
    Databank::UserRole::DEPOSITOR => "depositor",
    Databank::UserRole::GUEST => "guest",
    Databank::UserRole::NO_DEPOSIT => "no_deposit"
  }.freeze

  def initialize(user)
    @user = user
  end

  def as_json
    {
      type: "User",
      attributes: {
        provider: normalized_provider,
        uid: normalized_uid,
        email: normalized_email,
        username: normalized_username,
        name: normalized_name,
        role: user.role,
        mapped_role: mapped_role,
        created_at: user.created_at,
        updated_at: user.updated_at
      }
    }
  end

  def mapped_role
    ROLE_MAP[user.role.to_s]
  end

  def exportable?
    normalized_provider.present? && normalized_uid.present? && normalized_email.present? && mapped_role.present?
  end

  def skip_reason
    return "unsupported_role" if mapped_role.blank?
    return "missing_provider" if normalized_provider.blank?
    return "missing_uid" if normalized_uid.blank?
    return "invalid_email" if normalized_email.blank?

    nil
  end

  private

  attr_reader :user

  def normalized_provider
    user.provider.to_s.strip.presence
  end

  def normalized_uid
    user.uid.to_s.strip.presence
  end

  def normalized_email
    raw = user.email.to_s.strip.downcase
    return nil if raw.blank?
    return nil unless raw =~ URI::MailTo::EMAIL_REGEXP

    raw
  end

  def normalized_username
    user.username.to_s.strip.presence || normalized_email.to_s.split("@").first.presence
  end

  def normalized_name
    user.name.to_s.strip.presence || normalized_email
  end
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
    desc "Export legacy users to NDJSON with SHA256 artifacts"
    task export_users_bundle: :environment do
      output_root = ENV.fetch("OUTPUT_ROOT", Rails.root.join("tmp/migration_exports_users").to_s)

      timestamp = Time.current.utc.strftime("%Y%m%dT%H%M%SZ")
      run_dir = File.join(output_root, "users_#{timestamp}")
      FileUtils.mkdir_p(run_dir)

      bundle_file = "legacy_users.ndjson"
      bundle_path = File.join(run_dir, bundle_file)
      checksum_path = "#{bundle_path}.sha256"
      manifest_path = File.join(run_dir, "manifest.json")

      records = []
      counts_by_role = Hash.new(0)
      counts_by_mapped_role = Hash.new(0)
      skipped_counts = Hash.new(0)

      User.order(:id).find_each do |user|
        serializer = Migration::Legacy::UserExportSerializer.new(user)
        counts_by_role[user.role.to_s] += 1

        unless serializer.exportable?
          skipped_counts[serializer.skip_reason] += 1
          next
        end

        counts_by_mapped_role[serializer.mapped_role] += 1
        records << serializer.as_json
      end

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
          "User" => records.count,
          "by_role" => counts_by_role,
          "by_mapped_role" => counts_by_mapped_role,
          "skipped" => skipped_counts
        },
        sha256: checksum,
        format_version: 1
      }
      File.write(manifest_path, JSON.pretty_generate(manifest))

      puts "Bundle: #{bundle_path}"
      puts "Checksum: #{checksum_path}"
      puts "Manifest: #{manifest_path}"
      puts "Record count: #{records.count}"
      puts "Skipped unsupported_role: #{skipped_counts.fetch('unsupported_role', 0)}"
      puts "Skipped missing_provider: #{skipped_counts.fetch('missing_provider', 0)}"
      puts "Skipped missing_uid: #{skipped_counts.fetch('missing_uid', 0)}"
      puts "Skipped invalid_email: #{skipped_counts.fetch('invalid_email', 0)}"
    end

    desc "Export all legacy migration bundles in required order"
    task export_all: :environment do
      %w[
        migration:legacy:export_users_bundle
        migration:legacy:export_bundle
        migration:legacy:export_permissions_bundle
        migration:legacy:export_dataset_access_grants_bundle
        migration:legacy:export_guides_bundle
        migration:legacy:export_featured_researchers_bundle
        migration:legacy:export_medusa_ingests_bundle
        migration:legacy:export_download_metrics_bundle
        migration:legacy:export_audits_bundle
      ].each do |task_name|
        puts "Running #{task_name}"
        task = Rake::Task[task_name]
        task.reenable
        task.invoke
      end

      puts "Legacy export sequence complete."
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

    desc "Export legacy audits to NDJSON with SHA256 artifacts"
    task export_audits_bundle: :environment do # rubocop:disable Metrics/BlockLength
      output_root = ENV.fetch("OUTPUT_ROOT", Rails.root.join("tmp/migration_exports_audits").to_s)
      include_tests = ENV.fetch("INCLUDE_TESTS", "false").casecmp("true").zero?
      since_raw = ENV["SINCE"]
      until_raw = ENV["UNTIL"]

      since_time = since_raw.present? ? Time.zone.parse(since_raw) : nil
      until_time = until_raw.present? ? Time.zone.parse(until_raw) : nil

      timestamp = Time.current.utc.strftime("%Y%m%dT%H%M%SZ")
      run_dir = File.join(output_root, "audit_#{timestamp}")
      FileUtils.mkdir_p(run_dir)

      bundle_file = "legacy_audits.ndjson"
      bundle_path = File.join(run_dir, bundle_file)
      checksum_path = "#{bundle_path}.sha256"
      manifest_path = File.join(run_dir, "manifest.json")

      scope = Dataset.order(:id)
      scope = scope.where(is_test: false) unless include_tests
      scope = scope.where("updated_at >= ?", since_time) if since_time
      scope = scope.where("updated_at < ?", until_time) if until_time

      digest = Digest::SHA256.new
      count = 0
      counts_by_type = Hash.new(0)
      counts_by_action = Hash.new(0)

      File.open(bundle_path, "w") do |file|
        scope.find_each(batch_size: 100) do |dataset|
          audits = (dataset.audits.to_a + dataset.associated_audits.to_a).uniq(&:id)
          audits.sort_by { |audit| [ audit.created_at || Time.at(0), audit.id ] }.each do |audit|
            next unless Migration::Legacy::AuditExportSerializer::AUDITABLE_TYPES.include?(audit.auditable_type)

            line = JSON.generate(Migration::Legacy::AuditExportSerializer.new(audit: audit, dataset: dataset).as_json)
            file.write(line)
            file.write("\n")
            digest.update(line)
            digest.update("\n")
            count += 1
            counts_by_type[audit.auditable_type] += 1
            counts_by_action[audit.action.to_s] += 1
          end
        end
      end

      checksum = digest.hexdigest
      File.write(checksum_path, "#{checksum}  #{bundle_file}\n")

      manifest = {
        generated_at: Time.current.utc.iso8601,
        bundle_file: bundle_file,
        record_count: count,
        sha256: checksum,
        include_tests: include_tests,
        since: since_time&.iso8601,
        until: until_time&.iso8601,
        counts: {
          "Audit" => count,
          "by_auditable_type" => counts_by_type,
          "by_action" => counts_by_action
        }
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

    # Flat NDJSON export format for memory-efficient imports
    # Each entity type (dataset, datafile, nested_item) gets its own line with foreign key references
    class Migration::Legacy::FlatExportSerializer
      def self.serialize_dataset(dataset)
        {
          type: "dataset",
          dataset_id: dataset.key,
          title: dataset.title,
          identifier: dataset.identifier,
          publisher: dataset.publisher,
          publication_year: dataset.publication_year,
          description: dataset.description,
          license: dataset.license,
          corresponding_creator_name: dataset.corresponding_creator_name,
          depositor_name: dataset.depositor_name,
          depositor_email: dataset.depositor_email,
          owner_uid: owner_uid_for(dataset),
          subject: dataset.subject,
          keywords: dataset.keywords,
          publication_state: dataset.publication_state,
          hold_state: dataset.hold_state,
          release_date: dataset.release_date,
          embargo: dataset.embargo,
          is_test: dataset.is_test,
          is_import: dataset.is_import,
          tombstone_date: dataset.tombstone_date,
          dataset_version: dataset.dataset_version,
          nested_updated_at: dataset.nested_updated_at,
          created_at: dataset.created_at,
          updated_at: dataset.updated_at,
          creators: serialize_creators_contributors(dataset.creators),
          contributors: serialize_creators_contributors(dataset.contributors),
          funders: serialize_funders(dataset.funders),
          related_materials: serialize_related_materials(dataset.related_materials),
          notes: serialize_notes(dataset.notes),
          token: serialize_token(dataset)
        }
      end

      def self.serialize_datafile(dataset, datafile)
        {
          type: "datafile",
          dataset_id: dataset.key,
          datafile_id: datafile.web_id,
          web_id: datafile.web_id,
          binary_name: datafile.binary_name,
          binary_size: datafile.binary_size,
          medusa_id: datafile.medusa_id,
          storage_root: datafile.storage_root,
          storage_key: datafile.storage_key,
          description: datafile.description,
          peek_type: datafile.peek_type,
          peek_text: datafile.peek_text,
          created_at: datafile.created_at,
          updated_at: datafile.updated_at
        }
      end

      def self.serialize_nested_items(dataset, datafile)
        # Yield each nested item record with parent relationship
        items_by_parent = datafile.nested_items.order(:id).group_by(&:parent_id)
        
        # Use a lambda to handle recursive traversal
        serialize_items_recursive = lambda do |parent_id|
          (items_by_parent[parent_id] || []).each do |item|
            yield({
              type: "nested_item",
              dataset_id: dataset.key,
              datafile_id: datafile.web_id,
              item_id: "ni-#{item.id}",
              parent_item_id: item.parent_id.present? ? "ni-#{item.parent_id}" : nil,
              item_name: item.item_name,
              media_type: item.media_type,
              size: item.size,
              item_path: item.item_path,
              is_directory: item.is_directory,
              created_at: item.created_at,
              updated_at: item.updated_at
            })
            
            # Recursively yield children
            serialize_items_recursive.call(item.id)
          end
        end

        serialize_items_recursive.call(nil)
      end

      private

      def self.owner_uid_for(dataset)
        user = User.find_by(email: dataset.depositor_email)
        return user.uid if user&.uid.present?
        "legacy:#{dataset.depositor_email}" if dataset.depositor_email.present?
      end

      def self.serialize_creators_contributors(people)
        people.order(Arel.sql("row_position ASC NULLS LAST, id ASC")).map do |person|
          is_contact = if person.respond_to?(:is_contact)
                         person.is_contact
                       elsif person.respond_to?(:contact)
                         person.contact
                       else
                         false
                       end

          {
            name: person.institution_name.presence ||
                  [person.given_name, person.family_name].compact.join(" ").strip.presence ||
                  person.email,
            family_name: person.family_name,
            given_name: person.given_name,
            institution_name: person.institution_name,
            email: person.email,
            identifier: person.identifier,
            identifier_scheme: person.identifier_scheme,
            is_contact: is_contact,
            row_position: person.row_position
          }
        end
      end

      def self.serialize_funders(funders)
        funders.order(:id).map do |funder|
          {
            name: funder.name,
            identifier: funder.identifier,
            identifier_scheme: funder.identifier_scheme,
            grant: funder.grant
          }
        end
      end

      def self.serialize_related_materials(materials)
        materials.order(:id).map do |material|
          relation_types = if material.respond_to?(:relationship_arr)
                             material.relationship_arr
                           else
                             material.datacite_list.to_s.split(",").map(&:strip).reject(&:blank?)
                           end
          {
            title: material.citation.presence || material.link.presence || material.uri.presence || material.material_type.presence || "material",
            citation: material.citation,
            link: material.link,
            uri: material.uri,
            uri_type: material.uri_type,
            material_type: material.material_type,
            selected_type: material.selected_type,
            availability: material.availability,
            note: material.note,
            datacite_list: relation_types.join(",")
          }
        end
      end

      def self.serialize_notes(notes)
        notes.order(:created_at, :id).map do |note|
          {
            body: note.body,
            author: note.author,
            created_at: note.created_at
          }
        end
      end

      def self.serialize_token(dataset)
        token = Token.where(dataset_key: dataset.key).order(updated_at: :desc, id: :desc).first
        return nil unless token
        
        {
          identifier: token.identifier,
          expires: token.expires,
          created_at: token.created_at
        }
      end
    end

    desc "Export legacy datasets in flat NDJSON format (memory-efficient)"
    task export_bundle: :environment do # rubocop:disable Metrics/BlockLength
      output_root = ENV.fetch("OUTPUT_ROOT", Rails.root.join("tmp/migration_exports").to_s)
      include_tests = ENV.fetch("INCLUDE_TESTS", "false").casecmp("true").zero?
      since_raw = ENV["SINCE"]
      until_raw = ENV["UNTIL"]

      since_time = since_raw.present? ? Time.zone.parse(since_raw) : nil
      until_time = until_raw.present? ? Time.zone.parse(until_raw) : nil

      timestamp = Time.current.utc.strftime("%Y%m%dT%H%M%SZ")
      run_dir = File.join(output_root, "dataset_flat_#{timestamp}")
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

      total_datasets = scope.count
      puts "Exporting #{total_datasets} datasets in flat format..."

      digest = Digest::SHA256.new
      dataset_count = 0
      datafile_count = 0
      nested_item_count = 0
      start_time = Time.current

      File.open(bundle_path, "w") do |file|
        scope.find_each(batch_size: 50) do |dataset|
          # Write dataset record
          dataset_record = Migration::Legacy::FlatExportSerializer.serialize_dataset(dataset)
          line = JSON.generate(dataset_record)
          file.write(line)
          file.write("\n")
          digest.update(line)
          digest.update("\n")
          dataset_count += 1

          # Write datafile records and nested items
          dataset.datafiles.each do |datafile|
            datafile_record = Migration::Legacy::FlatExportSerializer.serialize_datafile(dataset, datafile)
            line = JSON.generate(datafile_record)
            file.write(line)
            file.write("\n")
            digest.update(line)
            digest.update("\n")
            datafile_count += 1

            # Write nested item records (streaming)
            Migration::Legacy::FlatExportSerializer.serialize_nested_items(dataset, datafile) do |item_record|
              line = JSON.generate(item_record)
              file.write(line)
              file.write("\n")
              digest.update(line)
              digest.update("\n")
              nested_item_count += 1
            end
          end

          if dataset_count % 10 == 0
            elapsed = (Time.current - start_time).to_i
            rate = dataset_count.to_f / elapsed
            remaining = ((total_datasets - dataset_count) / rate).to_i
            percent = (dataset_count.to_f / total_datasets * 100).round(1)
            puts "[#{percent}%] #{dataset_count}/#{total_datasets} datasets, #{datafile_count} datafiles, #{nested_item_count} items (#{elapsed}s elapsed, ~#{remaining}s remaining)"
          end
        end
      end

      checksum = digest.hexdigest
      File.write(checksum_path, "#{checksum}  #{bundle_file}\n")

      manifest = {
        generated_at: Time.current.utc.iso8601,
        bundle_file: bundle_file,
        format_version: 2,
        format_type: "flat",
        record_counts: {
          datasets: dataset_count,
          datafiles: datafile_count,
          nested_items: nested_item_count
        },
        sha256: checksum,
        include_tests: include_tests,
        since: since_time&.iso8601,
        until: until_time&.iso8601
      }
      File.write(manifest_path, JSON.pretty_generate(manifest))

      total_time = (Time.current - start_time).to_i
      puts "\n✓ Flat format export complete!"
      puts "Bundle: #{bundle_path}"
      puts "Checksum: #{checksum_path}"
      puts "Manifest: #{manifest_path}"
      puts "Datasets: #{dataset_count}"
      puts "Datafiles: #{datafile_count}"
      puts "Nested items: #{nested_item_count}"
      puts "Total time: #{total_time}s"
    end

    desc "Export a small test subset of datasets in flat NDJSON format"
    task export_test_bundle: :environment do
      output_root = ENV.fetch("OUTPUT_ROOT", Rails.root.join("tmp/migration_exports").to_s)
      explicit_keys = ENV["KEYS"].presence&.split(",")&.map(&:strip)

      timestamp = Time.current.utc.strftime("%Y%m%dT%H%M%SZ")
      run_dir = File.join(output_root, "dataset_flat_test_#{timestamp}")
      FileUtils.mkdir_p(run_dir)

      bundle_file = "legacy_datasets.ndjson"
      bundle_path = File.join(run_dir, bundle_file)
      checksum_path = "#{bundle_path}.sha256"
      manifest_path = File.join(run_dir, "manifest.json")

      # Allow explicit keys via env (covers seed records which have is_test: true)
      if explicit_keys.present?
        test_keys = explicit_keys
        puts "Using explicit KEYS: #{test_keys.join(', ')}"
      else
        # Find non-test datasets with nested items; fall back to seed keys if present
        seed_keys = %w[TESTIDB-MIGRATE1 TESTIDB-MIGRATE2 TESTIDB-MIGRATE3]
        seed_datasets = Dataset.where(key: seed_keys).order(:key)
        if seed_datasets.count == seed_keys.size
          test_keys = seed_keys
          puts "Using seed migration test datasets: #{test_keys.join(', ')}"
        else
          scope = Dataset.includes(:creators, :contributors, :funders, :related_materials, :datafiles, :notes)
                         .where(is_test: false)
                         .order(:id)
          test_keys = []
          scope.find_each do |dataset|
            has_nested = dataset.datafiles.any? { |df| df.nested_items.any? }
            if has_nested
              nested_count = dataset.datafiles.sum { |df| df.nested_items.count }
              test_keys << dataset.key
              puts "Including #{dataset.key}: #{nested_count} nested items"
              break if test_keys.length >= 3
            end
          end
          test_keys = scope.limit(3).pluck(:key) if test_keys.length < 3
        end
      end

      scope = Dataset.includes(:creators, :contributors, :funders, :related_materials, :datafiles, :notes)
                     .where(key: test_keys)
                     .order(:id)

      puts "Exporting #{test_keys.length} test datasets in flat format..."

      digest = Digest::SHA256.new
      dataset_count = 0
      datafile_count = 0
      nested_item_count = 0

      File.open(bundle_path, "w") do |file|
        scope.find_each do |dataset|
          dataset_record = Migration::Legacy::FlatExportSerializer.serialize_dataset(dataset)
          line = JSON.generate(dataset_record)
          file.write(line)
          file.write("\n")
          digest.update(line)
          digest.update("\n")
          dataset_count += 1

          dataset.datafiles.each do |datafile|
            datafile_record = Migration::Legacy::FlatExportSerializer.serialize_datafile(dataset, datafile)
            line = JSON.generate(datafile_record)
            file.write(line)
            file.write("\n")
            digest.update(line)
            digest.update("\n")
            datafile_count += 1

            Migration::Legacy::FlatExportSerializer.serialize_nested_items(dataset, datafile) do |item_record|
              line = JSON.generate(item_record)
              file.write(line)
              file.write("\n")
              digest.update(line)
              digest.update("\n")
              nested_item_count += 1
            end
          end

          puts "✓ #{dataset.key}: #{datafile_count} datafiles, #{nested_item_count} items"
        end
      end

      checksum = digest.hexdigest
      File.write(checksum_path, "#{checksum}  #{bundle_file}\n")

      manifest = {
        generated_at: Time.current.utc.iso8601,
        bundle_file: bundle_file,
        format_version: 2,
        format_type: "flat",
        test_bundle: true,
        record_counts: {
          datasets: dataset_count,
          datafiles: datafile_count,
          nested_items: nested_item_count
        },
        sha256: checksum
      }
      File.write(manifest_path, JSON.pretty_generate(manifest))

      puts "\n✓ Flat test bundle created!"
      puts "Bundle: #{bundle_path}"
      puts "Checksum: #{checksum_path}"
      puts "Manifest: #{manifest_path}"
      puts "Datasets: #{dataset_count}"
      puts "Datafiles: #{datafile_count}"
      puts "Nested items: #{nested_item_count}"
    end
  end
end

