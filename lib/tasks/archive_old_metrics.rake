# frozen_string_literal: true

desc "Generate all historical download metrics (calendar and fiscal years)"
task generate_all_download_metrics: :environment do
  puts "Starting generation of all historical download metrics..."

  current_cal_year = Metric.current_calendar_year
  current_fis_year = Metric.current_fiscal_year

  # Generate metrics for all years back to FIRST_DOWNLOAD_YEAR
  %i[dataset_downloads datafile_downloads].each do |metric_type|
    puts "\nGenerating #{metric_type}..."

    # Generate calendar year metrics
    (Metric::FIRST_DOWNLOAD_YEAR...current_cal_year).each do |year|
      puts "  Generating #{metric_type} for calendar year #{year}..."
      Metric.public_send("write_#{metric_type}_downloads_csv_by_year", year, :calendar)
    end

    # Generate fiscal year metrics (FY16 onwards)
    (16..current_fis_year - 1).each do |fy|
      puts "  Generating #{metric_type} for fiscal year FY#{format('%02d', fy)}..."
      Metric.public_send("write_#{metric_type}_downloads_csv_by_year", fy, :fiscal)
    end
  end

  puts "\nGeneration complete! All historical metrics are now in storage."
end

desc "Archive old (non-current) download metrics from public/ to storage"
task archive_old_metrics: :environment do
  puts "Starting archival of old download metrics..."

  current_cal_year = Metric.current_calendar_year
  current_fis_year = Metric.current_fiscal_year

  # Archive old dataset downloads
  %i[dataset_downloads datafile_downloads].each do |metric_type|
    # Check for old calendar year files
    previous_cal_year = current_cal_year - 1
    loop do
      filename = Metric.filename_for_year_metric(metric_type, previous_cal_year, :calendar)
      file_path = File.join(Rails.root, "public", filename)
      
      break unless File.exist?(file_path)

      puts "Archiving #{filename}..."
      storage_key = Metric.archive_metric_to_storage(file_path, metric_type, previous_cal_year, :calendar)
      puts "  → Stored as: #{storage_key}"

      previous_cal_year -= 1
      break if previous_cal_year < Metric::FIRST_DOWNLOAD_YEAR
    end

    # Check for old fiscal year files
    previous_fis_year = current_fis_year - 1
    loop do
      break if previous_fis_year < 16  # FY16 is 2016 fiscal year

      filename = Metric.filename_for_year_metric(metric_type, previous_fis_year, :fiscal)
      file_path = File.join(Rails.root, "public", filename)

      break unless File.exist?(file_path)

      puts "Archiving #{filename}..."
      storage_key = Metric.archive_metric_to_storage(file_path, metric_type, previous_fis_year, :fiscal)
      puts "  → Stored as: #{storage_key}"

      previous_fis_year -= 1
    end
  end

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
