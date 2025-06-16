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
    Metric.datasets_downloads_json_to_csv
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
    render METRICS_CONFIG[:funders_csv][:relative_path], layout: false
  end

  # Responds to `GET /metrics/archived_content_csv`
  def archived_content_csv
    render "public/archive_file_contents.csv", layout: false
  end

  # Responds to `GET /metrics/related_materials_csv`
  def related_materials_csv
    render METRICS_CONFIG[:related_materials_csv][:relative_path], layout: false
  end

  # Responds to `GET /metrics/refresh_dataset_downloads`
  def refresh_dataset_downloads
    Metric.write_dataset_downloads_json
    message = "Dataset downloads json refresh initiated. Refresh in a few minutes to check for new modified timestamp."
    render :index, alert: message
  end

  # Responds to `GET /metrics/refresh_datafile_downloads`
  def refresh_datafile_downloads
    Metric.write_datafile_downloads_json
    message = "Dataset downloads json refresh initiated. Refresh in a few minutes to check for new modified timestamp."
    redirect_to metrics_path, notice: message
  end

  # Responds to `GET /metrics/refresh_datasets_tsv`
  def refresh_datasets_tsv
    Metric.write_datasets_tsv
    message = "Datasets tsv refresh initiated. Refresh in a few minutes to check for new modified timestamp."
    redirect_to metrics_path, notice: message
  end

  # Responds to `GET /metrics/refresh_datafiles_csv`
  def refresh_datafiles_csv
    Metric.write_datafiles_csv
    message = "Datafiles csv refresh initiated. Refresh in a few minutes to check for new modified timestamp."
    redirect_to metrics_path, notice: message
  end

  # Responds to `GET /metrics/refresh_container_csv`
  def refresh_container_csv
    Metric.write_container_contents_csv
    message = "Container contents csv refresh initiated. Refresh in a few minutes to check for new modified timestamp."
    redirect_to metrics_path, notice: message
  end

  def refresh_funders_csv
    Metric.write_funders_csv
    message = "Funders csv refresh initiated. Refresh in a few minutes to check for new modified timestamp."
    redirect_to metrics_path, notice: message
  end

  def refresh_related_materials_csv
    Metric.write_related_materials_csv
    message = "Related materials csv refresh initiated. Refresh in a few minutes to check for new modified timestamp."
    redirect_to metrics_path, notice: message
  end

  def refresh_container_contents_csv
    Metric.write_container_contents_csv
    message = "Container contents csv refresh initiated. Refresh in a few minutes to check for new modified timestamp."
    redirect_to metrics_path, notice: message
  end 
end
