# frozen_string_literal: true

require "json"
require "digest"
require "fileutils"

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
      run_dir = File.join(output_root, timestamp)
      FileUtils.mkdir_p(run_dir)

      bundle_file = "legacy_datasets.ndjson"
      bundle_path = File.join(run_dir, bundle_file)
      checksum_path = "#{bundle_path}.sha256"
      manifest_path = File.join(run_dir, "manifest.json")

      scope = Dataset.includes(:creators, :contributors, :funders, :related_materials, :datafiles)
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
  end
end
