# frozen_string_literal: true

namespace :metrics do
  desc "generate metric.rb docs"
  task generate_docs: :environment do
    Metric.refresh_all
  end

  desc "generate dataset report files"
  task generate_dataset_reports: :environment do
    Metric.generate_datasets_reports
  end
end
