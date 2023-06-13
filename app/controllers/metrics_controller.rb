# frozen_string_literal: true

require "csv"
require "tempfile"

class MetricsController < ApplicationController
  def index
    @modified_times = Metric.modified_times
  end

  def dataset_downloads
    render "public/dataset_downloads.json", layout: false
  end

  def file_downloads
    render "public/datafile_downloads.json", layout: false
  end

  def datafiles_simple_list
    metadata_public_dataset_ids = Dataset.select(&:metadata_public?).pluck(:id)
    @datafiles = Datafile.where(dataset_id: metadata_public_dataset_ids)
  end

  def datasets_csv
    datasets = Dataset.select(&:metadata_public?)

    Tempfile.open("datasets_csv") do |t|
      CSV.open(t, "w") do |report|
        report << ["doi", "pub_date", "num_files", "num_bytes", "total_downloads", "num_relationships", "subject"]

        datasets.each do |dataset|
          report << [dataset.identifier.to_s,
                     dataset.ingest_datetime.to_date.iso8601.to_s,
                     dataset.release_date.iso8601.to_s,
                     dataset.datafiles.count.to_s,
                     dataset.total_filesize.to_s,
                     dataset.total_downloads.to_s,
                     dataset.num_external_relationships.to_s,
                     dataset.creators.count.to_s,
                     dataset.subject.to_s]
        end
      end

      send_file t.path, type:        "text/csv",
                        disposition: "attachment",
                        filename:    "datasets.csv"
    end
  end

  def datafiles_csv
    render METRICS_CONFIG[:datafiles_csv][:relative_path], layout: false
  end

  def funders_csv
    Tempfile.open("funders_csv") do |t|
      datasets = Dataset.select(&:metadata_public?)

      report = CSV.new(t)

      report << ["doi", "funder", "grant"]

      datasets.each do |dataset|
        dataset.funders.each do |funder|
          report << [dataset.identifier, funder.name, funder.grant]
        end
      end

      send_file t.path, type:        "text/csv",
                        disposition: "attachment",
                        filename:    "funders.csv"

      report.close(unlink_now = false)
    end
  end

  def archived_content_csv
    render "public/archive_file_contents.csv", layout: false
  end

  def related_materials_csv
    Tempfile.open("materials_csv") do |t|
      datasets = Dataset.select(&:metadata_public?)

      report = CSV.new(t)

      report << ["doi,datacite_relationship", "material_id_type", "material_id,material_type"]

      datasets.each do |dataset|
        dataset.related_materials.each do |material|
          datacite_arr = []

          if material.datacite_list && material.datacite_list != ""
            datacite_arr = material.datacite_list.split(",")
            # else
            #   report << ["#{dataset.identifier}", "", "#{material.uri_type}", "#{material.uri}", "#{material.selected_type}"]
          end

          datacite_arr.each do |relationship|
            if ["IsPreviousVersionOf", "IsNewVersionOf"].exclude?(relationship)
              report << [dataset.identifier.to_s, relationship.to_s, material.uri_type.to_s, material.uri.to_s, material.selected_type.to_s]
            end
          end
        end
      end

      send_file t.path, type:        "text/csv",
                        disposition: "attachment",
                        filename:    "related_materials.csv"

      report.close(unlink_now = false)
    end
  end

  def refresh_dataset_downloads
    Metric.write_dataset_downloads_json
    message = "Dataset downloads json refresh initiated. Refresh in a few minutes to check for new modified timestamp."
    respond_to do |format|
      format.html { render :index, alert: message }
      format.json { render json: {"message": message} }
    end
  end

  def refresh_datafile_downloads
    Metric.write_datafile_downloads_json
    message = "Dataset downloads json refresh initiated. Refresh in a few minutes to check for new modified timestamp."
    respond_to do |format|
      format.html { render :index, alert: message }
      format.json { render json: {"message": message} }
    end
  end

  def refresh_datafiles_csv
    Metric.write_datafiles_csv
    message = "Dataset csv refresh initiated. Refresh in a few minutes to check for new modified timestamp."
    respond_to do |format|
      format.html { render :index, alert: message }
      format.json { render json: {"message": message} }
    end
  end

  def refresh_container_csv
    Metric.write_container_contents_csv
    message = "Container contents csv refresh initiated. Refresh in a few minutes to check for new modified timestamp."
    respond_to do |format|
      format.html { render :index, alert: message }
      format.json { render json: {"message": message} }
    end
  end

end
