# frozen_string_literal: true

class Metric
  class << self
    def refresh_all
      Metric.write_dataset_downloads_json
      Metric.write_datafile_downloads_json
      Metric.write_datafiles_csv
      Metric.write_datasets_tsv
      Metric.write_container_contents_csv
    end

    def modified_times

      write_dataset_downloads_json unless File.exist?(METRICS_CONFIG[:dataset_downloads_json][:relative_path])
      raise StandardError.new("unable to create dataset downloads json") unless File.exist?(METRICS_CONFIG[:dataset_downloads_json][:relative_path])

      write_datafile_downloads_json unless File.exist?(METRICS_CONFIG[:datafile_downloads_json][:relative_path])
      raise StandardError.new("unable to create datafile downloads json") unless File.exist?(METRICS_CONFIG[:datafile_downloads_json][:relative_path])

      write_datafiles_csv unless File.exist?(METRICS_CONFIG[:datafiles_csv][:relative_path])
      raise StandardError.new("unable to create datafiles csv") unless File.exist?(METRICS_CONFIG[:datafiles_csv][:relative_path])

      write_datafiles_csv unless File.exist?(METRICS_CONFIG[:datasets_tsv][:relative_path])
      raise StandardError.new("unable to create datasets csv") unless File.exist?(METRICS_CONFIG[:datasets_tsv][:relative_path])

      write_container_contents_csv unless File.exist?(METRICS_CONFIG[:container_contents_csv][:relative_path])
      raise StandardError.new("unable to create container contents csv") unless File.exist?(METRICS_CONFIG[:container_contents_csv][:relative_path])

      sleep(1)

      dataset_downloads_time = File.mtime(METRICS_CONFIG[:dataset_downloads_json][:relative_path])
      datafile_downloads_time = File.mtime(METRICS_CONFIG[:datafile_downloads_json][:relative_path])
      datafiles_csv_time = File.mtime(METRICS_CONFIG[:datafiles_csv][:relative_path])
      datasets_tsv_time = File.mtime(METRICS_CONFIG[:datasets_tsv][:relative_path])
      container_csv_time = File.mtime(METRICS_CONFIG[:container_contents_csv][:relative_path])

      {dataset_downloads_json:  dataset_downloads_time.to_formatted_s(:long),
       datafile_downloads_json: datafile_downloads_time.to_formatted_s(:long),
       datafiles_csv:           datafiles_csv_time.to_formatted_s(:long),
       datasets_tsv:            datasets_tsv_time.to_formatted_s(:long),
       container_contents_csv:  container_csv_time.to_formatted_s(:long)}
    end

    def write_datasets_tsv
      target_path = METRICS_CONFIG[:datasets_tsv][:relative_path]

      datasets = Dataset.all_with_public_metadata

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

      File.open(target_path, "w") do |f|
        f.puts headings_row

        datasets.each do |dataset|
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
          values_row = values.join("\t")
          f.puts values_row
      end

    end

    def write_dataset_downloads_json
      target_path = METRICS_CONFIG[:dataset_downloads_json][:relative_path]
      File.open(target_path, "w") do |f|
        f.print %({"dataset_downloads":[)
        dataset_download_tallies = DatasetDownloadTally.public_tallies
        dataset_download_tallies.each_with_index do |row, i|
          row_json = {doi: row.doi, date: row.download_date, tally: row.tally}.to_json
          f.print "," unless i.zero?
          f.print row_json
          f.puts "]}" if i == (dataset_download_tallies.count - 1)
        end
      end
    end

    def write_datafile_downloads_json
      target_path = METRICS_CONFIG[:datafile_downloads_json][:relative_path]
      File.open(target_path, "w") do |f|
        f.print %({"datafile_downloads":[)
        file_public_tallies = FileDownloadTally.public_tallies
        file_public_tallies.each_with_index do |row, i|
          row_json = {doi: row.doi, file: row.filename, date: row.download_date, tally: row.tally}.to_json
          f.print "," unless i.zero?
          f.print row_json
          f.puts "]}" if i == (file_public_tallies.count - 1)
        end
      end
    end

    def write_datafiles_csv
      doi_filename_mimetype = MedusaInfo.doi_filename_mimetype
      render(json: {error: "mimetype map not found", status: 500}) && (return nil) unless doi_filename_mimetype

      datasets = Dataset.select(&:metadata_public?)
      target_path = METRICS_CONFIG[:datafiles_csv][:relative_path]
      File.open(target_path, "w") do |f|
        CSV.open(f, "w") do |report|
          report << ["doi", "pub_date", "filename", "file_format", "num_bytes", "total_downloads"]

          datasets.each do |dataset|
            dataset.datafiles.each do |datafile|
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
    end

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
