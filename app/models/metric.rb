# frozen_string_literal: true

##
# Encapsulates handling reports offered on the metrics page.

class Metric
  LOCK_KEYS = %i[dataset_downloads_json datafile_downloads_json datasets_tsv datafiles_csv container_contents_csv funders_csv related_materials_csv].freeze

  class << self

    ##
    # refresh all the metrics
    def refresh_all
      Metric.write_dataset_downloads_json
      Metric.write_datafile_downloads_json
      Metric.write_datafiles_csv
      Metric.write_datasets_tsv
      Metric.write_container_contents_csv
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
      LOCK_KEYS.each_with_object({}) do |key, hash|
        hash[key] = in_progress?(key)
      end
    end

    ##
    # Create the lock file for the given metric key.
    # @param metric_key [Symbol]
    def set_in_progress(metric_key)
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
      raise StandardError.new("unable to create dataset downloads json") unless File.exist?(METRICS_CONFIG[:dataset_downloads_json][:relative_path])

      write_datafile_downloads_json unless File.exist?(METRICS_CONFIG[:datafile_downloads_json][:relative_path])
      raise StandardError.new("unable to create datafile downloads json") unless File.exist?(METRICS_CONFIG[:datafile_downloads_json][:relative_path])

      write_datafiles_csv unless File.exist?(METRICS_CONFIG[:datafiles_csv][:relative_path])
      raise StandardError.new("unable to create datafiles csv") unless File.exist?(METRICS_CONFIG[:datafiles_csv][:relative_path])

      write_datasets_tsv unless File.exist?(METRICS_CONFIG[:datasets_tsv][:relative_path])
      raise StandardError.new("unable to create datasets tsv") unless File.exist?(METRICS_CONFIG[:datasets_tsv][:relative_path])

      write_container_contents_csv unless File.exist?(METRICS_CONFIG[:container_contents_csv][:relative_path])
      raise StandardError.new("unable to create container contents csv") unless File.exist?(METRICS_CONFIG[:container_contents_csv][:relative_path])

      write_funders_csv unless File.exist?(METRICS_CONFIG[:funders_csv][:relative_path])
      raise StandardError.new("unable to create funders csv") unless File.exist?(METRICS_CONFIG[:funders_csv][:relative_path])

      write_related_materials_csv unless File.exist?(METRICS_CONFIG[:related_materials_csv][:relative_path])
      raise StandardError.new("unable to create related materials csv") unless File.exist?(METRICS_CONFIG[:related_materials_csv][:relative_path])
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

      { dataset_downloads_json: dataset_downloads_time.to_formatted_s(:long),
        datafile_downloads_json: datafile_downloads_time.to_formatted_s(:long),
        datafiles_csv: datafiles_csv_time.to_formatted_s(:long),
        datasets_tsv: datasets_tsv_time.to_formatted_s(:long),
        container_contents_csv: container_csv_time.to_formatted_s(:long),
        funders_csv: funders_csv_time.to_formatted_s(:long),
        related_materials_csv: related_materials_csv_time.to_formatted_s(:long) }
    end

    ##
    # write the datasets tsv
    # Processes datasets one at a time via find_each to limit memory usage.
    # @return [void]
    def write_datasets_tsv
      metric_key = :datasets_tsv
      return if in_progress?(metric_key)

      set_in_progress(metric_key)
      begin
        target_path = METRICS_CONFIG[metric_key][:relative_path]
        headings = %w[doi ingest_date release_date num_files num_bytes total_downloads
                      num_relationships num_creators subject citation_text]
        File.open(target_path, "w") do |f|
          f.puts headings.join("\t")
          Dataset.find_each do |dataset|
            next unless dataset.metadata_public?

            dataset.handle_related_materials
            values = [dataset.identifier.to_s,
                      dataset.ingest_datetime.to_date.iso8601.to_s,
                      dataset.release_date.iso8601.to_s,
                      dataset.datafiles.count.to_s,
                      dataset.total_filesize.to_s,
                      dataset.total_downloads.to_s,
                      dataset.num_external_relationships.to_s,
                      dataset.creators.count.to_s,
                      dataset.subject.to_s,
                      dataset.plain_text_citation]
            f.puts values.join("\t")
          end
        end
      ensure
        clear_in_progress(metric_key)
      end
    end

    ##
    # write the dataset downloads json
    # Processes tallies in batches to limit memory usage.
    # Each record is written on its own line for line-by-line processability.
    def write_dataset_downloads_json
      metric_key = :dataset_downloads_json
      return if in_progress?(metric_key)

      set_in_progress(metric_key)
      begin
        batch_size = IDB_CONFIG[:batch_size] || 500
        target_path = METRICS_CONFIG[metric_key][:relative_path]
        doi_totals_hash = {}
        first_record = true
        File.open(target_path, "w") do |f|
          f.puts %({"dataset_downloads":[)
          DatasetDownloadTally.find_in_batches(batch_size: batch_size) do |batch|
            batch.each do |row|
              row_json = { doi: row.doi, date: row.download_date, tally: row.tally }.to_json
              if doi_totals_hash.key?(row.doi)
                doi_totals_hash[row.doi] += row.tally
              else
                doi_totals_hash[row.doi] = row.tally
              end
              f.puts(first_record ? row_json : ",#{row_json}")
              first_record = false
            end
          end
          f.puts "]}"
        end
        totals_path = target_path.split(".json").first + "_totals.csv"
        File.open(totals_path, "w") do |f|
          f.puts "doi,tally"
          doi_totals_hash.each do |doi, tally|
            f.puts "#{doi},#{tally}"
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
      return if in_progress?(metric_key)

      set_in_progress(metric_key)
      begin
        batch_size = IDB_CONFIG[:batch_size] || 500
        target_path = METRICS_CONFIG[metric_key][:relative_path]
        first_record = true
        File.open(target_path, "w") do |f|
          f.puts %({"datafile_downloads":[)
          FileDownloadTally.find_in_batches(batch_size: batch_size) do |batch|
            batch.each do |row|
              row_json = { doi: row.doi, file: row.filename, date: row.download_date, tally: row.tally }.to_json
              f.puts(first_record ? row_json : ",#{row_json}")
              first_record = false
            end
          end
          f.puts "]}"
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
      return if in_progress?(metric_key)

      set_in_progress(metric_key)
      begin
        doi_filename_mimetype = MedusaInfo.doi_filename_mimetype
        render(json: { error: "mimetype map not found", status: 500 }) && (return nil) unless doi_filename_mimetype

        batch_size = IDB_CONFIG[:batch_size] || 500
        target_path = METRICS_CONFIG[metric_key][:relative_path]
        File.open(target_path, "w") do |f|
          CSV.open(f, "w") do |report|
            report << ["doi", "pub_date", "filename", "file_format", "num_bytes", "total_downloads"]
          end
        end
        Dataset.find_each do |dataset|
          next unless dataset.metadata_public?

          dataset.datafiles.each_slice(batch_size) do |datafiles|
            write_datafile_csv_datafile_batch(target_path, dataset, datafiles, doi_filename_mimetype)
          end
        end
      ensure
        clear_in_progress(metric_key)
      end
    end

    ##
    # write the datafile csv datafile batch
    # @param target_path [String] the target path
    # @param dataset [Dataset] the dataset
    # @param datafiles [Array] the datafiles
    # @param doi_filename_mimetype [Hash] the doi, filename, and mimetype
    def write_datafile_csv_datafile_batch(target_path, dataset, datafiles, doi_filename_mimetype)
      File.open(target_path, "a") do |f|
        CSV.open(f, "a") do |report|
          datafiles.each do |datafile|
            doi_filename = "#{dataset.identifier}_#{datafile.bytestream_name}".downcase
            report << [dataset.identifier.to_s,
                       dataset.release_date.iso8601.to_s,
                       datafile.bytestream_name.to_s,
                       (doi_filename_mimetype[doi_filename]).to_s,
                       datafile.bytestream_size.to_s,
                       datafile.total_downloads.to_s]
          end
        end
      end
    end

    ##
    # write_container_contents_csv
    # Processes datasets one at a time via find_each to limit memory usage.
    # @return [void]
    def write_container_contents_csv
      metric_key = :container_contents_csv
      return if in_progress?(metric_key)

      set_in_progress(metric_key)
      begin
        target_path = METRICS_CONFIG[metric_key][:relative_path]
        File.open(target_path, "w") do |f|
          CSV.open(f, "w") do |report|
            report << ["doi", "container_filename", "content_filepath", "content_filename", "file_format"]
            Dataset.find_each do |dataset|
              next unless dataset.metadata_public?

              dataset.datafiles.each do |datafile|
                next unless datafile.archive?

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
      return if in_progress?(metric_key)

      set_in_progress(metric_key)
      begin
        target_path = METRICS_CONFIG[metric_key][:relative_path]
        File.open(target_path, "w") do |f|
          CSV.open(f, "w") do |report|
            report << ["doi", "funder", "grant"]
            Dataset.find_each do |dataset|
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
      return if in_progress?(metric_key)

      set_in_progress(metric_key)
      begin
        target_path = METRICS_CONFIG[metric_key][:relative_path]
        File.open(target_path, "w") do |f|
          CSV.open(f, "w") do |report|
            report << ["doi", "datacite_relationship", "material_id_type", "material_id", "material_type"]
            Dataset.find_each do |dataset|
              next unless dataset.metadata_public?

              dataset.related_materials.each do |material|
                datacite_arr = (material.datacite_list.presence || "").split(",")
                datacite_arr.each do |relationship|
                  next if ["IsPreviousVersionOf", "IsNewVersionOf"].include?(relationship)

                  report << [dataset.identifier.to_s, relationship.to_s, material.uri_type.to_s, material.uri.to_s, material.selected_type.to_s]
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
    # generate_datasets_reports
    # This method writes a dataset report for the most recent version of each dataset with public metadata
    # There are two reports written: a csv and plain text report
    # the csv has everything except the description
    # the plain text report has the description and metadata to connect it to the csv
    # request detail: a report for the Data Bank from beginning to now that includes: DOI, Pub Date, Funder, Title, Keywords, Descriptions, Corresponding Creator, Subject
    # @return [void]
    def generate_datasets_reports
      csv_target_path = METRICS_CONFIG[:dataset_report_csv][:relative_path]
      text_target_path = METRICS_CONFIG[:dataset_report_text][:relative_path]
      csv_file = File.open(csv_target_path, "w")
      text_file = File.open(text_target_path, "w")
      begin
        CSV.open(csv_file, "w", force_quotes: false) do |report|
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
          Dataset.find_each do |dataset|
            next unless dataset.metadata_public?
            next unless dataset.is_most_recent_version

            report << [
              dataset.key,
              dataset.identifier,
              dataset.release_date.iso8601.to_s,
              dataset.funders.any? ? dataset.funders.map { |f| "#{f.name} (#{f.grant})" }.join("; ") : nil,
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
      ensure
        csv_file.close
        text_file.close
      end
    end
  end
end