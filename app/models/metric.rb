# frozen_string_literal: true

require "tempfile"

##
# Encapsulates handling reports offered on the metrics page.

class Metric
  LOCK_KEYS = [:dataset_downloads_csv, :datafile_downloads_csv, :datasets_tsv, :datafiles_csv,
               :container_contents_csv, :funders_csv, :related_materials_csv].freeze
  MIMETYPE_DEFAULT = "application/octet-stream"
  DATASETS_TSV_HEADINGS = ["doi", "ingest_date", "release_date", "num_files", "num_bytes", "total_downloads",
                           "num_relationships", "num_creators", "subject", "citation_text"].freeze
  CONTAINER_CONTENTS_CSV_HEADINGS = ["doi", "container_filename", "content_filepath", "content_filename",
                                     "file_format"].freeze
  RELATED_MATERIALS_CSV_HEADINGS = ["doi", "datacite_relationship", "material_id_type", "material_id",
                                    "material_type"].freeze
  VERSION_RELATIONSHIPS = ["IsPreviousVersionOf", "IsNewVersionOf"].freeze
  DATASET_REPORT_CSV_HEADINGS = ["key", "doi", "release_date", "funders", "title", "keywords",
                                 "corresponding_creator", "subject"].freeze

  Definition = Struct.new(:key, :config, keyword_init: true) do
    def label
      value = config[:label] || config["label"]
      return value if value

      key.to_s.tr("_", " ")
    end

    def relative_path
      config[:relative_path] || config["relative_path"]
    end

    def download_path
      path = config[:download_path] || config["download_path"]
      return path if path

      absolute = relative_path.to_s
      root_prefix = Rails.root.to_s
      return absolute.delete_prefix(root_prefix) if absolute.start_with?(root_prefix)

      "/#{File.basename(absolute)}"
    end

    def content_type
      value = config[:content_type] || config["content_type"]
      return value if value

      case File.extname(relative_path.to_s)
      when ".json"
        "application/json"
      when ".csv"
        "text/csv"
      when ".tsv"
        "text/tab-separated-values"
      when ".txt"
        "text/plain"
      else
        "application/octet-stream"
      end
    end

    def summary
      config[:summary] || config["summary"]
    end

    def description_blocks
      value = config[:description_blocks] || config["description_blocks"]
      return [] unless value

      value
    end

    def columns
      value = config[:columns] || config["columns"]
      return [] unless value

      value
    end

    def help_url
      config[:help_url] || config["help_url"]
    end

    def show_in_admin?
      return config[:show_in_admin] unless config[:show_in_admin].nil?
      return config["show_in_admin"] unless config["show_in_admin"].nil?

      refreshable?
    end

    def lock_path
      "#{relative_path}.lock"
    end

    def refreshable?
      return config[:refreshable] unless config[:refreshable].nil?
      return config["refreshable"] unless config["refreshable"].nil?

      Metric::LOCK_KEYS.include?(key)
    end

    def writer_method
      method = config[:write_method] || config["write_method"]
      return method.to_sym if method

      "write_#{key}".to_sym
    end

    def display_name
      label
    end

    def in_progress?
      File.exist?(lock_path)
    end

    def mark_in_progress
      FileUtils.touch(lock_path)
    end

    def clear_in_progress
      File.delete(lock_path) if File.exist?(lock_path)
    end
  end

  class << self
    ##
    # refresh all refreshable metrics
    def refresh_metrics
      refreshable_definitions.each do |definition|
        public_send(writer_method_for(definition.key))
      end
    end

    ##
    # @param metric_key [Symbol] key from METRICS_CONFIG
    # @return [String] path to the lock file for the given metric
    def lock_path(metric_key)
      definition_for(metric_key).lock_path
    end

    ##
    # @param metric_key [Symbol] key from METRICS_CONFIG
    # @return [Boolean] true if a refresh is currently in progress for this metric
    def in_progress?(metric_key)
      definition_for(metric_key).in_progress?
    end

    ##
    # @return [Hash] map of metric_key => Boolean indicating in-progress state for each metric
    def refresh_status
      refreshable_definitions.each_with_object({}) do |definition, statuses|
        statuses[definition.key] = definition.in_progress?
      end
    end

    ##
    # Create the lock file for the given metric key.
    # @param metric_key [Symbol]
    def mark_in_progress(metric_key)
      definition_for(metric_key).mark_in_progress
    end

    ##
    # Remove the lock file for the given metric key.
    # @param metric_key [Symbol]
    def clear_in_progress(metric_key)
      definition_for(metric_key).clear_in_progress
    end

    ##
    # @return [Hash] the modified times of the metrics
    def modified_times
      refreshable_definitions.each do |definition|
        ensure_metric_file_present(definition)
      end

      refreshable_definitions.each_with_object({}) do |definition, hash|
        hash[definition.key] = File.mtime(definition.relative_path).to_formatted_s(:long)
      end
    end

    def definitions
      METRICS_CONFIG.each_with_object([]) do |(raw_key, raw_config), arr|
        metric_key = raw_key.to_sym
        metric_config = raw_config.respond_to?(:to_h) ? raw_config.to_h : {}
        arr << Definition.new(key: metric_key, config: metric_config)
      end
    end

    def definition_for(metric_key)
      normalized_key = metric_key.to_sym
      definition = definitions.find {|item| item.key == normalized_key }
      raise ArgumentError, "Unknown metric key: #{metric_key}" unless definition

      definition
    end

    def refreshable_definitions
      definitions.select(&:refreshable?).sort_by do |definition|
        LOCK_KEYS.index(definition.key) || LOCK_KEYS.length
      end
    end

    def admin_definitions
      definitions.select(&:show_in_admin?).sort_by do |definition|
        LOCK_KEYS.index(definition.key) || LOCK_KEYS.length
      end
    end

    def writer_method_for(metric_key)
      definition = definition_for(metric_key)
      writer_method = definition.writer_method
      return writer_method if respond_to?(writer_method)

      raise ArgumentError, "No writer method found for metric key: #{metric_key}"
    end

    def ensure_metric_file_present(definition)
      return if File.exist?(definition.relative_path)

      public_send(writer_method_for(definition.key))
      return if File.exist?(definition.relative_path)

      raise StandardError, "unable to create #{definition.display_name}"
    end

    ##
    # write the dataset downloads csv
    # Processes tallies in batches to limit memory usage.
    # @return [void]
    def write_dataset_downloads_csv
      metric_key = :dataset_downloads_csv
      mark_in_progress(metric_key)
      begin
        batch_size = IDB_CONFIG[:batch_size] || 500
        target_path = METRICS_CONFIG[metric_key][:relative_path]
        write_metric_files_atomically(target_path) do |temp_paths|
          CSV.open(temp_paths[target_path], "w") do |report|
            report << ["doi", "date", "tally"]
            DatasetDownloadTally.find_in_batches(batch_size: batch_size) do |batch|
              batch.each do |row|
                report << [row.doi, row.download_date, row.tally]
              end
            end
          end
        end
      ensure
        clear_in_progress(metric_key)
      end
    end

    ##
    # write the datafile downloads csv
    # Processes tallies in batches to limit memory usage.
    # @return [void]
    def write_datafile_downloads_csv
      metric_key = :datafile_downloads_csv
      mark_in_progress(metric_key)
      begin
        batch_size = IDB_CONFIG[:batch_size] || 500
        target_path = METRICS_CONFIG[metric_key][:relative_path]
        write_metric_files_atomically(target_path) do |temp_paths|
          CSV.open(temp_paths[target_path], "w") do |report|
            report << ["doi", "file", "date", "tally"]
            FileDownloadTally.find_in_batches(batch_size: batch_size) do |batch|
              batch.each do |row|
                report << [row.doi, row.filename, row.download_date, row.tally]
              end
            end
          end
        end
      ensure
        clear_in_progress(metric_key)
      end
    end

    ##
    # write the datasets tsv
    # Processes datasets one at a time via find_each to limit memory usage.
    # @return [void]
    def write_datasets_tsv
      metric_key = :datasets_tsv
      mark_in_progress(metric_key)
      begin
        batch_size = IDB_CONFIG[:batch_size] || 500
        target_path = METRICS_CONFIG[metric_key][:relative_path]
        write_metric_files_atomically(target_path) do |temp_paths|
          File.open(temp_paths[target_path], "w") do |file|
            file.puts DATASETS_TSV_HEADINGS.join("\t")
            Dataset.find_each(batch_size: batch_size) do |dataset|
              next unless dataset.metadata_public?

              dataset.handle_related_materials
              file.puts datasets_tsv_row(dataset).join("\t")
            end
          end
        end
      ensure
        clear_in_progress(metric_key)
      end
    end

    def datasets_tsv_row(dataset)
      [dataset.identifier.to_s,
       dataset.ingest_datetime.to_date.iso8601,
       dataset.release_date.iso8601,
       dataset.datafiles.count,
       dataset.total_filesize,
       dataset.total_downloads,
       dataset.num_external_relationships,
       dataset.creators.count,
       dataset.subject.to_s,
       dataset.plain_text_citation]
    end

    ##
    # write the datafiles csv
    # Processes datasets in batches; datafiles in batches per dataset.
    # @return [void]
    def write_datafiles_csv
      metric_key = :datafiles_csv
      mark_in_progress(metric_key)
      begin
        batch_size = IDB_CONFIG[:batch_size] || 500
        target_path = METRICS_CONFIG[metric_key][:relative_path]
        write_metric_files_atomically(target_path) do |temp_paths|
          CSV.open(temp_paths[target_path], "w") do |report|
            report << ["doi", "pub_date", "filename", "file_format", "num_bytes"]
            Dataset.find_in_batches(batch_size: batch_size) do |datasets|
              datasets.each do |dataset|
                next unless dataset.metadata_public?

                dataset.datafiles.reorder(nil).find_in_batches(batch_size: batch_size) do |datafiles|
                  write_datafile_csv_batch(report, dataset, datafiles)
                end
              end
            end
          end
        end
      ensure
        clear_in_progress(metric_key)
      end
    end

    ##
    # write the datafile csv datafile batch
    # @param report [CSV] the report writer
    # @param dataset [Dataset] the dataset
    # @param datafiles [Array] the datafiles
    def write_datafile_csv_batch(report, dataset, datafiles)
      return if datafiles.empty?

      datafiles.each do |datafile|
        report << [dataset.identifier.to_s,
                   dataset.release_date.iso8601.to_s,
                   datafile.bytestream_name.to_s,
                   datafile.mime_type || MIMETYPE_DEFAULT,
                   datafile.bytestream_size]
      end
    end

    ##
    # write_container_contents_csv
    # Processes datasets one at a time via find_each to limit memory usage.
    # @return [void]
    def write_container_contents_csv
      metric_key = :container_contents_csv
      mark_in_progress(metric_key)
      begin
        batch_size = IDB_CONFIG[:batch_size] || 500
        target_path = METRICS_CONFIG[metric_key][:relative_path]
        write_metric_files_atomically(target_path) do |temp_paths|
          CSV.open(temp_paths[target_path], "w") do |report|
            report << CONTAINER_CONTENTS_CSV_HEADINGS
            Dataset.find_each(batch_size: batch_size) do |dataset|
              next unless dataset.metadata_public?

              archive_datafiles_relation(dataset).find_each(batch_size: batch_size) do |datafile|
                write_container_contents_rows(report, dataset, datafile)
              end
            end
          end
        end
      ensure
        clear_in_progress(metric_key)
      end
    end

    def archive_datafiles_relation(dataset)
      dataset.datafiles
             .where(peek_type: Databank::PeekType::LISTING)
             .includes(:nested_items)
             .reorder(nil)
    end

    def write_container_contents_rows(report, dataset, datafile)
      datafile.nested_items.each do |item|
        report << [dataset.identifier.to_s,
                   datafile.bytestream_name.to_s,
                   item.item_path,
                   item.item_name,
                   item.media_type]
      end
    end

    ##
    # write_funders_csv
    # Processes datasets one at a time via find_each to limit memory usage.
    # @return [void]
    def write_funders_csv
      metric_key = :funders_csv
      mark_in_progress(metric_key)
      begin
        batch_size = IDB_CONFIG[:batch_size] || 500
        target_path = METRICS_CONFIG[metric_key][:relative_path]
        write_metric_files_atomically(target_path) do |temp_paths|
          CSV.open(temp_paths[target_path], "w") do |report|
            report << ["doi", "funder", "grant"]
            Dataset.find_each(batch_size: batch_size) do |dataset|
              next unless dataset.metadata_public?

              dataset.funders.each do |funder|
                report << [dataset.identifier, funder.name, funder.grant]
              end
            end
          end
        end
      ensure
        clear_in_progress(metric_key)
      end
    end

    ##
    # write_related_materials_csv
    # Processes datasets one at a time via find_each to limit memory usage.
    # @return [void]
    def write_related_materials_csv
      metric_key = :related_materials_csv
      mark_in_progress(metric_key)
      begin
        batch_size = IDB_CONFIG[:batch_size] || 500
        target_path = METRICS_CONFIG[metric_key][:relative_path]
        write_metric_files_atomically(target_path) do |temp_paths|
          CSV.open(temp_paths[target_path], "w") do |report|
            report << RELATED_MATERIALS_CSV_HEADINGS
            Dataset.find_each(batch_size: batch_size) do |dataset|
              next unless dataset.metadata_public?

              dataset.related_materials.each do |material|
                write_related_materials_rows(report, dataset, material)
              end
            end
          end
        end
      ensure
        clear_in_progress(metric_key)
      end
    end

    def write_related_materials_rows(report, dataset, material)
      related_material_relationships(material).each do |relationship|
        report << [dataset.identifier.to_s, relationship.to_s, material.uri_type.to_s, material.uri.to_s,
                   material.selected_type.to_s]
      end
    end

    def related_material_relationships(material)
      (material.datacite_list.presence || "")
        .split(",")
        .reject {|relationship| VERSION_RELATIONSHIPS.include?(relationship) }
    end

    def write_json_array_rows(writer, root_key, relation, batch_size: IDB_CONFIG[:batch_size] || 500)
      first_record = true
      writer.puts %({"#{root_key}":[)
      relation.find_in_batches(batch_size: batch_size) do |batch|
        batch.each do |row|
          row_json = yield(row).to_json
          writer.puts(first_record ? row_json : ",#{row_json}")
          first_record = false
        end
      end
      writer.puts "]}"
    end

    def write_metric_files_atomically(*target_paths) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
      temp_files = target_paths.each_with_object({}) do |target_path, hash|
        extension = File.extname(target_path)
        basename = File.basename(target_path, extension)
        hash[target_path] = Tempfile.new([basename, extension], File.dirname(target_path))
      end

      begin
        yield temp_files.transform_values(&:path)
        temp_files.each_value(&:flush)
        temp_files.each_value(&:close)
        temp_files.each do |target_path, temp_file|
          FileUtils.mv(temp_file.path, target_path)
        end
      ensure
        temp_files.each_value do |temp_file|
          temp_file.close unless temp_file.closed?
          File.delete(temp_file.path) if File.exist?(temp_file.path)
        end
      end
    end

    ##
    # generate_datasets_reports
    # This method writes a dataset report for the most recent version of each dataset with public metadata
    # There are two reports written: a csv and plain text report
    # the csv has everything except the description
    # the plain text report has the description and metadata to connect it to the csv
    # request detail: a report for the Data Bank from beginning to now that includes: DOI, Pub Date, Funder, Title, Keywords, Descriptions, Corresponding Creator, Subject
    # @return [void]
    def generate_datasets_reports
      batch_size = IDB_CONFIG[:batch_size] || 500
      csv_target_path = METRICS_CONFIG[:dataset_report_csv][:relative_path]
      text_target_path = METRICS_CONFIG[:dataset_report_text][:relative_path]
      write_metric_files_atomically(csv_target_path, text_target_path) do |temp_paths|
        File.open(temp_paths[text_target_path], "w") do |text_file|
          CSV.open(temp_paths[csv_target_path], "w", force_quotes: false) do |report|
            report << DATASET_REPORT_CSV_HEADINGS
            Dataset.find_each(batch_size: batch_size) do |dataset|
              next unless include_in_dataset_reports?(dataset)

              report << dataset_report_csv_row(dataset)
              text_file.write(dataset_report_text_block(dataset))
            end
          end
        end
      end
    end

    def include_in_dataset_reports?(dataset)
      dataset.metadata_public? && dataset.is_most_recent_version
    end

    def dataset_report_csv_row(dataset)
      [dataset.key,
       dataset.identifier,
       dataset.release_date.iso8601.to_s,
       dataset_report_funders_value(dataset),
       dataset.title,
       dataset.keywords,
       dataset_report_corresponding_creator_value(dataset),
       dataset.subject]
    end

    def dataset_report_funders_value(dataset)
      return nil unless dataset.funders.any?

      dataset.funders.map {|funder| "#{funder.name} (#{funder.grant})" }.join("; ")
    end

    def dataset_report_corresponding_creator_value(dataset)
      "#{dataset.corresponding_creator_name} | #{dataset.corresponding_creator_email}"
    end

    def dataset_report_text_block(dataset)
      "Key: #{dataset.key}\n" \
        "Citation: #{dataset.plain_text_citation}\n" \
        "Description: #{dataset.description}\n" \
        "----------------------------------------\n\n"
    end
  end
end
