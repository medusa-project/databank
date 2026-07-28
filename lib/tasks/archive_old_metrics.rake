# frozen_string_literal: true

desc "Generate all historical download metrics (calendar and fiscal years)"
task generate_all_download_metrics: :environment do
  puts "Starting generation of all historical download metrics..."
  Metric.generate_all_historical_downloads
  puts "\nGeneration complete! All historical metrics are now in storage."
end

desc "Archive old (non-current) download metrics from public/ to storage"
task archive_old_metrics: :environment do
  puts "Starting archival of old download metrics..."
  Metric.archive_prior_year_downloads_to_storage
  puts "Archival complete!"
end

desc "List archived download metrics in storage"
task list_archived_metrics: :environment do
  puts "Archived download metrics in storage:"
  puts "Note: Listing all archived metrics requires StorageManager support for key listing"
  puts "Currently stored metrics can be retrieved via:"
  puts "  GET /metrics/archived/:metric_type/:year/:slice_type"
  puts ""
  puts "Example URLs:"
  puts "  /metrics/archived/dataset_downloads/2025/calendar"
  puts "  /metrics/archived/datafile_downloads/FY25/fiscal"
end
