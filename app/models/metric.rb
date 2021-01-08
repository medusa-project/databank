# frozen_string_literal: true

class Metric
  class << self
    def refresh_all
      Metric.write_dataset_downloads_json
      Metric.write_datafile_downloads_json
      Metric.write_datafiles_csv
      Metric.write_container_contents_csv
    end

    def write_dataset_downloads_json
      target_path = Rails.root.join("public/dataset_downloads.json")
      File.open(target_path, "w") do |f|
        f.print %Q({"dataset_downloads":[)
        DatasetDownloadTally.all.each do |row|
          row_json = {doi: row.doi, date: row.download_date, tally: row.tally}.to_json
          f.print "," unless row == row.first
          if row == row.last
            f.print row_json
            f.puts "]}"
          else
            f.puts row_json
          end
        end
      end
    end

    def write_datafile_downloads_json
      target_path = Rails.root.join("public/datafile_downloads.json")
      File.open(target_path, "w") do |f|
        f.print %Q({"datafile_downloads":[)
        FileDownloadTally.all.each do |row|
          f.print "," unless row == row.first
          row_json = {doi: row.doi, file: row.filename, date: row.download_date, tally: row.tally}.to_json
          if row == row.last
            f.print row_json
            f.puts "]}"
          else
            f.puts row_json
          end
        end
      end
    end

    def write_datafiles_csv
      doi_filename_mimetype = MedusaInfo.doi_filename_mimetype
      render(json: {error: "mimetype map not found", status: 500}) && (return nil) unless doi_filename_mimetype

      datasets = Dataset.where.not(publication_state: Databank::PublicationState::DRAFT)
      target_path = Rails.root.join("public/datafiles.csv")
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
      datasets = Dataset.where.not(publication_state: Databank::PublicationState::DRAFT)
      target_path = Rails.root.join("public/archive_file_contents.csv")
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
