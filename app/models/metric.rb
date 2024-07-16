# frozen_string_literal: true

##
# Encapsulates handling reports offered on the metrics page.

class Metric
  class << self
    ##
    # write csv of dataset download metrics derived from the dataset_downloads.json
    def datasets_downloads_json_to_csv
      tally_hash = {}
      json_path = METRICS_CONFIG[:dataset_downloads_json][:relative_path]
      File.foreach(json_path) do |line|
        parsed = JSON.parse(line)
        if tally_hash.key?(parsed["doi"])
          tally_hash[parsed["doi"]] += parsed["tally"]
        else
          tally_hash[parsed["doi"]] = parsed["tally"]
        end
      end


      dataset_downloads_json = JSON.parse(File.read(METRICS_CONFIG[:dataset_downloads_json][:relative_path]))
      dataset_downloads_csv = "#{Rails.root}/public/dataset_downloads.csv"
      downloads_hash = {}
      dataset_downloads_json["dataset_downloads"].each do |row|
        if downloads_hash.key?(row["doi"])
          downloads_hash[row["doi"]] += row["tally"]
        else
          downloads_hash[row["doi"]] = row["tally"]
        end
      end
      CSV.open(dataset_downloads_csv, "w") do |csv|
        csv << ["doi", "date", "tally"]
        downloads_hash.each do |doi, tally|
          csv << [doi, tally]
        end
      end
    end

    ##
    # refresh all the metrics
    def refresh_all
      Metric.write_dataset_downloads_json
      Metric.write_datafile_downloads_json
      Metric.write_datafiles_csv
      Metric.write_datasets_tsv
      Metric.write_container_contents_csv
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

      sleep(1)

      dataset_downloads_time = File.mtime(METRICS_CONFIG[:dataset_downloads_json][:relative_path])
      datafile_downloads_time = File.mtime(METRICS_CONFIG[:datafile_downloads_json][:relative_path])
      datafiles_csv_time = File.mtime(METRICS_CONFIG[:datafiles_csv][:relative_path])
      datasets_tsv_time = File.mtime(METRICS_CONFIG[:datasets_tsv][:relative_path])
      container_csv_time = File.mtime(METRICS_CONFIG[:container_contents_csv][:relative_path])

      { dataset_downloads_json: dataset_downloads_time.to_formatted_s(:long),
        datafile_downloads_json: datafile_downloads_time.to_formatted_s(:long),
        datafiles_csv: datafiles_csv_time.to_formatted_s(:long),
        datasets_tsv: datasets_tsv_time.to_formatted_s(:long),
        container_contents_csv: container_csv_time.to_formatted_s(:long) }
    end

    ##
    # write the datasets tsv
    def write_datasets_tsv
      target_path = METRICS_CONFIG[:datasets_tsv][:relative_path]
      datasets = Dataset.all_with_public_metadata
      download_tally_hash = DatasetDownloadTally.public_tally_count_by_dataset_key
      headings = ["doi",
                  "ingest_date",
                  "release_date",
                  "num_files",
                  "num_bytes",
                  "total_downloads",
                  "num_relationships",
                  "num_creators",
                  "subject",
                  "citation_text"]
      headings_row = headings.join("\t")
      values_rows = []
      datasets.each do |dataset|
        dataset.handle_related_materials
        download_tally_hash[dataset.key] = 0 if download_tally_hash[dataset.key].nil?
        values = [dataset.identifier.to_s,
                  dataset.ingest_datetime.to_date.iso8601.to_s,
                  dataset.release_date.iso8601.to_s,
                  dataset.datafiles.count.to_s,
                  dataset.total_filesize.to_s,
                  download_tally_hash[dataset.key].to_s,
                  dataset.num_external_relationships.to_s,
                  dataset.creators.count.to_s,
                  dataset.subject.to_s,
                  dataset.plain_text_citation]
        values_row = values.join("\t")
        values_rows << "#{values_row}\n"
      end
      File.open(target_path, "w") do |f|
        f.puts headings_row
        f.puts values_rows
      end
    end

    ##
    # write the dataset downloads json
    def write_dataset_downloads_json
      target_path = METRICS_CONFIG[:dataset_downloads_json][:relative_path]
      doi_totals_hash = {}
      File.open(target_path, "w") do |f|
        f.print %({"dataset_downloads":[)
        dataset_download_tallies = DatasetDownloadTally.public_tallies
        dataset_download_tallies.each_with_index do |row, i|
          row_json = { doi: row.doi, date: row.download_date, tally: row.tally }.to_json
          if doi_totals_hash.key?(row.doi)
            doi_totals_hash[row.doi] += row.tally
          else
            doi_totals_hash[row.doi] = row.tally
          end
          f.print "," unless i.zero?
          f.print row_json
          f.puts "]}" if i == (dataset_download_tallies.count - 1)
        end
      end
      totals_path = target_path.split(".json").first + "_totals.csv"
      File.open(totals_path, "w") do |f|
        f.puts "doi,tally"
        doi_totals_hash.each do |doi, tally|
          f.puts "#{doi},#{tally}"
      end
    end

    ##
    # write the datafile downloads json
    def write_datafile_downloads_json
      target_path = METRICS_CONFIG[:datafile_downloads_json][:relative_path]
      File.open(target_path, "w") do |f|
        f.print %({"datafile_downloads":[)
        file_public_tallies = FileDownloadTally.public_tallies
        file_public_tallies.each_with_index do |row, i|
          row_json = { doi: row.doi, file: row.filename, date: row.download_date, tally: row.tally }.to_json
          f.print "," unless i.zero?
          f.print row_json
          f.puts "]}" if i == (file_public_tallies.count - 1)
        end
      end
    end

    ##
    # write the datafiles csv
    def write_datafiles_csv
      doi_filename_mimetype = MedusaInfo.doi_filename_mimetype
      render(json: { error: "mimetype map not found", status: 500 }) && (return nil) unless doi_filename_mimetype
      datasets = Dataset.select(&:metadata_public?)
      target_path = METRICS_CONFIG[:datafiles_csv][:relative_path]
      File.open(target_path, "w") do |f|
        CSV.open(f, "w") do |report|
          report << ["doi", "pub_date", "filename", "file_format", "num_bytes", "total_downloads"]
        end
      end
      public_downloads_by_web_id = FileDownloadTally.public_downloads_by_web_id
      datasets.each do |dataset|
        # divide into batches of 1000
        # write each batch to the file
        dataset.datafiles.each_slice(1000) do |datafiles|
          write_datafile_csv_datafile_batch(target_path, dataset, datafiles, doi_filename_mimetype, public_downloads_by_web_id)
        end
      end
    end

    ##
    # write the datafile csv datafile batch
    # @param target_path [String] the target path
    # @param dataset [Dataset] the dataset
    # @param datafiles [Array] the datafiles
    # @param doi_filename_mimetype [Hash] the doi, filename, and mimetype
    def write_datafile_csv_datafile_batch(target_path, dataset, datafiles, doi_filename_mimetype, public_downloads_by_web_id)
      File.open(target_path, "a") do |f|
        CSV.open(f, "a") do |report|
          datafiles.each do |datafile|
            doi_filename = "#{dataset.identifier}_#{datafile.bytestream_name}".downcase
            public_downloads_by_web_id[datafile.web_id] = 0 if public_downloads_by_web_id[datafile.web_id].nil?
            report << [dataset.identifier.to_s,
                       dataset.release_date.iso8601.to_s,
                       datafile.bytestream_name.to_s,
                       (doi_filename_mimetype[doi_filename]).to_s,
                       datafile.bytestream_size.to_s,
                       public_downloads_by_web_id[datafile.web_id].to_s]
          end
        end
      end
    end

    ##
    # write_container_contents_csv
    # This method is used to write the container contents csv
    def write_container_contents_csv
      datasets = Dataset.all_with_public_metadata
      target_path = METRICS_CONFIG[:container_contents_csv][:relative_path]
      File.open(target_path, "w") do |f|
        CSV.open(f, "w") do |report|
          report << ["doi", "container_filename", "content_filepath", "content_filename", "file_format"]
          datasets.each do |dataset|
            dataset.datafiles.each do |datafile|
              next unless datafile.archive?

              content_files = datafile.nested_items
              content_files.each do |item|
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
    end
  end
end