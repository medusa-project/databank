# frozen_string_literal: true

require "csv"
require "tempfile"

class MetricsController < ApplicationController

  # Responds to `GET /metrics`
  def index
    @modified_times = Metric.modified_times
  end

  # Responds to `GET /metrics/downloads`
  def downloads
    datasets_downloads_json_to_csv
    @dataset_downloads_csv_path = "#{Rails.root}/public/dataset_downloads.csv"
    @dataset_overview_tsv_path = "#{Rails.root}/public/datasets.tsv"
  end

  # Responds to `GET /metrics/dataset_downloads`
  def dataset_downloads
    render "public/dataset_downloads.json", layout: false
  end

  # Responds to `GET /metrics/file_downloads`
  def file_downloads
    render "public/datafile_downloads.json", layout: false
  end

  # Responds to `GET /metrics/datafiles`
  def datafiles_simple_list
    metadata_public_dataset_ids = Dataset.select(&:metadata_public?).pluck(:id)
    @datafiles = Datafile.where(dataset_id: metadata_public_dataset_ids)
  end

  # @deprecated - interface just uses public/datasets.tsv filepath
  # for example: https://databank.illinois.edu/datasets.tsv
  def datasets_tsv
    render METRICS_CONFIG[:datasets_tsv][:relative_path], layout: false
  end

  # @deprecated - interface just uses public/datafiles.csv filepath
  # for example: https://databank.illinois.edu/datafiles.csv
  def datafiles_csv
    render METRICS_CONFIG[:datafiles_csv][:relative_path], layout: false
  end

  # Responds to `GET /metrics/funders_csv`
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

  # Responds to `GET /metrics/archived_content_csv`
  def archived_content_csv
    render "public/archive_file_contents.csv", layout: false
  end

  # Responds to `GET /metrics/related_materials_csv`
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

  # Responds to `GET /metrics/refresh_dataset_downloads`
  def refresh_dataset_downloads
    Metric.write_dataset_downloads_json
    message = "Dataset downloads json refresh initiated. Refresh in a few minutes to check for new modified timestamp."
    respond_to do |format|
      format.html { render :index, alert: message }
      format.json { render json: {"message": message} }
    end
  end

  # Responds to `GET /metrics/refresh_datafile_downloads`
  def refresh_datafile_downloads
    Metric.write_datafile_downloads_json
    message = "Dataset downloads json refresh initiated. Refresh in a few minutes to check for new modified timestamp."
    respond_to do |format|
      format.html { render :index, alert: message }
      format.json { render json: {"message": message} }
    end
  end

  # Responds to `GET /metrics/refresh_datasets_tsv`
  def refresh_datasets_tsv
    Metric.write_datasets_tsv
    message = "Datasets tsv refresh initiated. Refresh in a few minutes to check for new modified timestamp."
    respond_to do |format|
      format.html { render :index, alert: message }
      format.json { render json: {"message": message} }
    end
  end

  # Responds to `GET /metrics/refresh_datafiles_csv`
  def refresh_datafiles_csv
    Metric.write_datafiles_csv
    message = "Datafiles csv refresh initiated. Refresh in a few minutes to check for new modified timestamp."
    respond_to do |format|
      format.html { render :index, alert: message }
      format.json { render json: {"message": message} }
    end
  end

  # Responds to `GET /metrics/refresh_container_csv`
  def refresh_container_csv
    Metric.write_container_contents_csv
    message = "Container contents csv refresh initiated. Refresh in a few minutes to check for new modified timestamp."
    respond_to do |format|
      format.html { render :index, alert: message }
      format.json { render json: {"message": message} }
    end
  end

end
