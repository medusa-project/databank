# frozen_string_literal: true

require "csv"
require "tempfile"

class MetricsController < ApplicationController

  # Responds to `GET /metrics`
  def index
    @modified_times = Metric.modified_times
    @title = "Metrics"
  end

  # Responds to `GET /metrics/dataset_downloads`
  def dataset_downloads
    serve_metrics_file(Rails.root.join("public/dataset_downloads.json"), type: "application/json")
  end

  # Responds to `GET /metrics/file_downloads`
  def file_downloads
    serve_metrics_file(Rails.root.join("public/datafile_downloads.json"), type: "application/json")
  end

  # Responds to `GET /metrics/datafiles`
  def datafiles_simple_list
    metadata_public_dataset_ids = Dataset.select(&:metadata_public?).pluck(:id)
    @datafiles = Datafile.where(dataset_id: metadata_public_dataset_ids)
  end

  # @deprecated - interface just uses public/datasets.tsv filepath
  # for example: https://databank.illinois.edu/datasets.tsv
  def datasets_tsv
    serve_metrics_file(METRICS_CONFIG[:datasets_tsv][:relative_path], type: "text/tab-separated-values")
  end

  # @deprecated - interface just uses public/datafiles.csv filepath
  # for example: https://databank.illinois.edu/datafiles.csv
  def datafiles_csv
    serve_metrics_file(METRICS_CONFIG[:datafiles_csv][:relative_path], type: "text/csv")
  end

  # Responds to `GET /metrics/funders_csv`
  def funders_csv
    serve_metrics_file(METRICS_CONFIG[:funders_csv][:relative_path], type: "text/csv")
  end

  # Responds to `GET /metrics/archived_content_csv`
  def archived_content_csv
    serve_metrics_file(Rails.root.join("public/archive_file_contents.csv"), type: "text/csv")
  end

  # Responds to `GET /metrics/related_materials_csv`
  def related_materials_csv
    serve_metrics_file(METRICS_CONFIG[:related_materials_csv][:relative_path], type: "text/csv")
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

  private

  def serve_metrics_file(path, type:)
    file_path = path.to_s
    return head :not_found unless File.file?(file_path)

    send_file file_path, type: type, disposition: "inline"
  end
end
