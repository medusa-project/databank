# frozen_string_literal: true

require "csv"
require "tempfile"

class MetricsController < ApplicationController

  # Responds to `GET /metrics`
  def index
    @title = "Metrics"
    render layout: false
  end

  def admin_metrics
    authorize! :manage, :all
    @modified_times = Metric.modified_times
    @refresh_status = Metric.refresh_status
    @title = "Admin metrics"
  rescue CanCan::AccessDenied
    redirect_to IDB_CONFIG[:root_url_text],
                alert: "You are not authorized to access the requested resource."
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
    enqueue_metric_refresh(:dataset_downloads_json, "Dataset downloads JSON")
  end

  # Responds to `GET /metrics/refresh_datafile_downloads`
  def refresh_datafile_downloads
    enqueue_metric_refresh(:datafile_downloads_json, "Datafile downloads JSON")
  end

  # Responds to `GET /metrics/refresh_datasets_tsv`
  def refresh_datasets_tsv
    enqueue_metric_refresh(:datasets_tsv, "Datasets TSV")
  end

  # Responds to `GET /metrics/refresh_datafiles_csv`
  def refresh_datafiles_csv
    enqueue_metric_refresh(:datafiles_csv, "Datafiles CSV")
  end

  # Responds to `GET /metrics/refresh_container_csv`
  def refresh_container_csv
    enqueue_metric_refresh(:container_contents_csv, "Container contents CSV")
  end

  def refresh_funders_csv
    enqueue_metric_refresh(:funders_csv, "Funders CSV")
  end

  def refresh_related_materials_csv
    enqueue_metric_refresh(:related_materials_csv, "Related materials CSV")
  end

  def refresh_container_contents_csv
    enqueue_metric_refresh(:container_contents_csv, "Container contents CSV")
  end

  private

  def enqueue_metric_refresh(metric_key, label)
    if Metric.in_progress?(metric_key)
      redirect_to metrics_path, alert: "#{label} refresh is already in progress. Please refresh the page to check status."
    else
      begin
        Metric.set_in_progress(metric_key)
        MetricRefreshJob.new(metric_key).delay.perform
        redirect_to metrics_path, notice: "#{label} refresh started. Please refresh this page manually to check for an updated status."
      rescue StandardError => e
        Metric.clear_in_progress(metric_key)
        Rails.logger.error("Unable to enqueue metric refresh for #{metric_key}: #{e.message}")
        redirect_to metrics_path, alert: "Unable to start #{label} refresh right now. Please try again."
      end
    end
  end

  def serve_metrics_file(path, type:)
    file_path = path.to_s
    return head :not_found unless File.file?(file_path)

    send_file file_path, type: type, disposition: "inline"
  end
end
