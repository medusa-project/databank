# frozen_string_literal: true

##
# Background job for regenerating a single metrics file.
# Enqueued via delayed_job: MetricRefreshJob.new(metric_key).delay.perform
#
# @param metric_key [Symbol] one of Metric::LOCK_KEYS
class MetricRefreshJob
  def initialize(metric_key)
    @metric_key = metric_key.to_sym
  end

  def perform
    method_name = Metric.writer_method_for(@metric_key)
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
