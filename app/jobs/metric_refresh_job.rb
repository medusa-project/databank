# frozen_string_literal: true

##
# Background job for regenerating a single metrics file.
# Enqueued via delayed_job: MetricRefreshJob.new(metric_key).delay.perform
#
# @param metric_key [Symbol] one of Metric::LOCK_KEYS
class MetricRefreshJob
  METRIC_KEY_TO_METHOD = {
    dataset_downloads_json: :write_dataset_downloads_json,
    datafile_downloads_json: :write_datafile_downloads_json,
    datasets_tsv: :write_datasets_tsv,
    datafiles_csv: :write_datafiles_csv,
    container_contents_csv: :write_container_contents_csv,
    funders_csv: :write_funders_csv,
    related_materials_csv: :write_related_materials_csv
  }.freeze

  def initialize(metric_key)
    @metric_key = metric_key.to_sym
  end

  def perform
    method_name = METRIC_KEY_TO_METHOD[@metric_key]
    raise ArgumentError, "Unknown metric key: #{@metric_key}" unless method_name

    Metric.public_send(method_name)
  end

  def success(_job)
    Rails.logger.info("MetricRefreshJob succeeded for metric: #{@metric_key}")
  end

  def error(_job, exception)
    Rails.logger.error("MetricRefreshJob error for metric #{@metric_key}: #{exception.message}")
    Metric.clear_in_progress(@metric_key)
  end

  def failure(_job)
    Rails.logger.error("MetricRefreshJob permanently failed for metric: #{@metric_key}")
    Metric.clear_in_progress(@metric_key)
  end
end
