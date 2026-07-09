# frozen_string_literal: true

require "tempfile"

##
# Encapsulates handling reports offered on the metrics page.

class Metric
  LOCK_KEYS = [:dataset_downloads_json, :datafile_downloads_json, :datasets_tsv, :datafiles_csv,
               :container_contents_csv, :funders_csv, :related_materials_csv].freeze
  MIMETYPE_DEFAULT = "application/octet-stream"

  class << self
    ##
    # refresh all the metrics
    def refresh_all
      Metric.write_dataset_downloads_json
      # Metric.write_datafile_downloads_json
      # Metric.write_datafiles_csv
      Metric.write_datasets_tsv
      # Metric.write_container_contents_csv
      Metric.write_funders_csv
      Metric.write_related_materials_csv
    end

    ##
    # @param metric_key [Symbol] key from METRICS_CONFIG
    # @return [String] path to the lock file for the given metric
    def lock_path(metric_key)
      "#{METRICS_CONFIG[metric_key][:relative_path]}.lock"
    end

    ##
    # @param metric_key [Symbol] key from METRICS_CONFIG
    # @return [Boolean] true if a refresh is currently in progress for this metric
    def in_progress?(metric_key)
      File.exist?(lock_path(metric_key))
    end

    ##
    # @return [Hash] map of metric_key => Boolean indicating in-progress state for each metric
    def refresh_status
      LOCK_KEYS.index_with do |key|
        in_progress?(key)
      end
    end

    ##
    # Create the lock file for the given metric key.
    # @param metric_key [Symbol]
    def mark_in_progress(metric_key)
      FileUtils.touch(lock_path(metric_key))
    end

    ##
    # Remove the lock file for the given metric key.
    # @param metric_key [Symbol]
    def clear_in_progress(metric_key)
      path = lock_path(metric_key)
      File.delete(path) if File.exist?(path)
    end

    ##
    # @return [Hash] the modified times of the metrics
    def modified_times
      write_dataset_downloads_json unless File.exist?(METRICS_CONFIG[:dataset_downloads_json][:relative_path])
      unless File.exist?(METRICS_CONFIG[:dataset_downloads_json][:relative_path])
        raise StandardError.new("unable to create dataset downloads json")
      end

      write_datafile_downloads_json unless File.exist?(METRICS_CONFIG[:datafile_downloads_json][:relative_path])
      unless File.exist?(METRICS_CONFIG[:datafile_downloads_json][:relative_path])
        raise StandardError.new("unable to create datafile downloads json")
      end

      write_datafiles_csv unless File.exist?(METRICS_CONFIG[:datafiles_csv][:relative_path])
      unless File.exist?(METRICS_CONFIG[:datafiles_csv][:relative_path])
        raise StandardError.new("unable to create datafiles csv")
      end

      write_datasets_tsv unless File.exist?(METRICS_CONFIG[:datasets_tsv][:relative_path])
      unless File.exist?(METRICS_CONFIG[:datasets_tsv][:relative_path])
        raise StandardError.new("unable to create datasets tsv")
      end

      write_container_contents_csv unless File.exist?(METRICS_CONFIG[:container_contents_csv][:relative_path])
      unless File.exist?(METRICS_CONFIG[:container_contents_csv][:relative_path])
        raise StandardError.new("unable to create container contents csv")
      end

      write_funders_csv unless File.exist?(METRICS_CONFIG[:funders_csv][:relative_path])
      unless File.exist?(METRICS_CONFIG[:funders_csv][:relative_path])
        raise StandardError.new("unable to create funders csv")
      end

      write_related_materials_csv unless File.exist?(METRICS_CONFIG[:related_materials_csv][:relative_path])
      unless File.exist?(METRICS_CONFIG[:related_materials_csv][:relative_path])
        raise StandardError.new("unable to create related materials csv")
      end

      # wait a second to ensure the files are written
      # This is necessary because the file system may not update the modified time immediately

      sleep(1)

      dataset_downloads_time = File.mtime(METRICS_CONFIG[:dataset_downloads_json][:relative_path])
      datafile_downloads_time = File.mtime(METRICS_CONFIG[:datafile_downloads_json][:relative_path])
      datafiles_csv_time = File.mtime(METRICS_CONFIG[:datafiles_csv][:relative_path])
      datasets_tsv_time = File.mtime(METRICS_CONFIG[:datasets_tsv][:relative_path])
      container_csv_time = File.mtime(METRICS_CONFIG[:container_contents_csv][:relative_path])
      funders_csv_time = File.mtime(METRICS_CONFIG[:funders_csv][:relative_path])
      related_materials_csv_time = File.mtime(METRICS_CONFIG[:related_materials_csv][:relative_path])

      {dataset_downloads_json:  dataset_downloads_time.to_formatted_s(:long),
       datafile_downloads_json: datafile_downloads_time.to_formatted_s(:long),
       datafiles_csv:           datafiles_csv_time.to_formatted_s(:long),
       datasets_tsv:            datasets_tsv_time.to_formatted_s(:long),
       container_contents_csv:  container_csv_time.to_formatted_s(:long),
       funders_csv:             funders_csv_time.to_formatted_s(:long),
       related_materials_csv:   related_materials_csv_time.to_formatted_s(:long)}
    end

    ##
    # write the dataset downloads json
    # Processes tallies in batches to limit memory usage.
    # Each record is written on its own line for line-by-line processability.
    def write_dataset_downloads_json
      metric_key = :dataset_downloads_json
      mark_in_progress(metric_key)
      begin
        batch_size = IDB_CONFIG[:batch_size] || 500
        target_path = METRICS_CONFIG[metric_key][:relative_path]
        totals_path = "#{target_path.split('.json').first}_totals.csv"
        doi_totals_hash = {}
        write_metric_files_atomically(target_path, totals_path) do |temp_paths|
          File.open(temp_paths[target_path], "w") do |f|
            write_json_array_rows(f, "dataset_downloads", DatasetDownloadTally, batch_size: batch_size) do |row|
              doi_totals_hash[row.doi] = doi_totals_hash.fetch(row.doi, 0) + row.tally
              {doi: row.doi, date: row.download_date, tally: row.tally}
            end
          end

          File.open(temp_paths[totals_path], "w") do |f|
            f.puts "doi,tally"
            doi_totals_hash.each do |doi, tally|
              f.puts "#{doi},#{tally}"
            end
          end
        end
      ensure
        clear_in_progress(metric_key)
      end
    end

    ##
    # write the datafile downloads json
    # Processes tallies in batches to limit memory usage.
    # Each record is written on its own line for line-by-line processability.
    def write_datafile_downloads_json
      metric_key = :datafile_downloads_json
      mark_in_progress(metric_key)
      begin
        batch_size = IDB_CONFIG[:batch_size] || 500
        target_path = METRICS_CONFIG[metric_key][:relative_path]
        write_metric_files_atomically(target_path) do |temp_paths|
          File.open(temp_paths[target_path], "w") do |f|
            write_json_array_rows(f, "datafile_downloads", FileDownloadTally, batch_size: batch_size) do |row|
              {doi: row.doi, file: row.filename, date: row.download_date, tally: row.tally}
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
        headings = ["doi", "ingest_date", "release_date", "num_files", "num_bytes", "total_downloads",
                    "num_relationships", "num_creators", "subject", "citation_text"]
        write_metric_files_atomically(target_path) do |temp_paths|
          File.open(temp_paths[target_path], "w") do |f|
            f.puts headings.join("\t")
            Dataset.find_each(batch_size: batch_size) do |dataset|
              next unless dataset.metadata_public?

              dataset.handle_related_materials
              values = [dataset.identifier.to_s,
                        dataset.ingest_datetime.to_date.iso8601,
                        dataset.release_date.iso8601,
                        dataset.datafiles.count,
                        dataset.total_filesize,
                        dataset.total_downloads,
                        dataset.num_external_relationships,
                        dataset.creators.count,
                        dataset.subject.to_s,
                        dataset.plain_text_citation]
              f.puts values.join("\t")
            end
          end
        end
      ensure
        clear_in_progress(metric_key)
      end
    end

    ##
    # write the datafiles csv
    # Processes datasets one at a time via find_each; datafiles in batches per dataset.
    # @return [void]
    def write_datafiles_csv
      metric_key = :datafiles_csv
      mark_in_progress(metric_key)
      begin
        content_type_manifest = MedusaInfo.content_type_manifest
        unless content_type_manifest && content_type_manifest["records"]
          Rails.logger.error("Unable to write datafiles csv: content type manifest is missing or invalid")
          return
        end

        batch_size = IDB_CONFIG[:batch_size] || 500
        target_path = METRICS_CONFIG[metric_key][:relative_path]
        write_metric_files_atomically(target_path) do |temp_paths|
          CSV.open(temp_paths[target_path], "w") do |report|
            report << ["doi", "pub_date", "filename", "file_format", "num_bytes", "total_downloads"]
            Dataset.find_each(batch_size: batch_size) do |dataset|
              next unless dataset.metadata_public?

              dataset.datafiles.reorder(nil).find_in_batches(batch_size: batch_size) do |datafiles|
                write_datafile_csv_datafile_batch(report, dataset, datafiles, content_type_manifest)
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
    # @param content_type_manifest [Hash] the content type manifest
    def write_datafile_csv_datafile_batch(report, dataset, datafiles, content_type_manifest)
      return if datafiles.empty?

      dataset_identifier = dataset.identifier.to_s
      release_date = dataset.release_date.iso8601.to_s
      paths = datafiles.map(&:medusa_path)
      mimetypes = MedusaInfo.mimetype_batch(paths: paths, manifest: content_type_manifest)
      datafiles.each_with_index do |datafile, index|
        medusa_path = paths[index]
        report << [dataset_identifier,
                   release_date,
                   datafile.bytestream_name.to_s,
                   mimetypes[medusa_path] || MIMETYPE_DEFAULT,
                   datafile.bytestream_size,
                   datafile.total_downloads]
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
            report << ["doi", "container_filename", "content_filepath", "content_filename", "file_format"]
            Dataset.find_each(batch_size: batch_size) do |dataset|
              next unless dataset.metadata_public?

              dataset.datafiles.where(peek_type: Databank::PeekType::LISTING).includes(:nested_items).reorder(nil).find_each(batch_size: batch_size) do |datafile|
                datafile.nested_items.each do |item|
                  report << [dataset.identifier.to_s,
                             datafile.bytestream_name.to_s,
                             item.item_path,
                             item.item_name,
                             item.media_type]
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
            report << ["doi", "datacite_relationship", "material_id_type", "material_id", "material_type"]
            Dataset.find_each(batch_size: batch_size) do |dataset|
              next unless dataset.metadata_public?

              dataset.related_materials.each do |material|
                datacite_arr = (material.datacite_list.presence || "").split(",")
                datacite_arr.each do |relationship|
                  next if ["IsPreviousVersionOf", "IsNewVersionOf"].include?(relationship)

                  report << [dataset.identifier.to_s, relationship.to_s, material.uri_type.to_s, material.uri.to_s,
                             material.selected_type.to_s]
                end
              end
            end
          end
        end
      ensure
        clear_in_progress(metric_key)
      end
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

    def write_metric_files_atomically(*target_paths)
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
            report << [
              "key",
              "doi",
              "release_date",
              "funders",
              "title",
              "keywords",
              "corresponding_creator",
              "subject"
            ]
            Dataset.find_each(batch_size: batch_size) do |dataset|
              next unless dataset.metadata_public?
              next unless dataset.is_most_recent_version

              report << [
                dataset.key,
                dataset.identifier,
                dataset.release_date.iso8601.to_s,
                dataset.funders.any? ? dataset.funders.map {|f| "#{f.name} (#{f.grant})" }.join("; ") : nil,
                dataset.title,
                dataset.keywords,
                "#{dataset.corresponding_creator_name} | #{dataset.corresponding_creator_email}",
                dataset.subject
              ]
              text_file.puts "Key: #{dataset.key}\n"
              text_file.puts "Citation: #{dataset.plain_text_citation}\n"
              text_file.puts "Description: #{dataset.description}\n"
              text_file.puts "----------------------------------------\n\n"
            end
          end
        end
      end
    end
  end
end
