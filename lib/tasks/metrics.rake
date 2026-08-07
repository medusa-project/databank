# frozen_string_literal: true

namespace :metrics do
  desc "generate metric.rb docs"
  task generate_docs: :environment do
    Metric.refresh_metrics
  end

  desc "force write current download metrics only"
  task :force_write_download_metrics => :environment do
    Metric.write_dataset_downloads_csv_orchestrator
    Metric.write_datafile_downloads_csv_orchestrator
  end

  desc "generate metric files if they don't exist or if more than a day old"
  task ensure_fresh_metrics: :environment do
    Metric.ensure_fresh_metrics
  end

  desc "generate dataset report files"
  task generate_dataset_reports: :environment do
    Metric.generate_datasets_reports
  end
end
