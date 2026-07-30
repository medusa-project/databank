# frozen_string_literal: true

namespace :dev_data do
  desc "Generate sample download metrics data for local testing (dev and test environments only)"
  task generate_sample_downloads: :environment do
    unless Rails.env.development? || Rails.env.test?
      puts "❌ This task is only for development and test! Current environment: #{Rails.env}"
      return
    end

    puts "🔄 Generating sample download data for existing test datasets...\n"

    # Get all existing datasets and datafiles
    datasets = Dataset.all
    if datasets.empty?
      puts "❌ No datasets found. Run 'bin/setup_local' first to create test fixtures."
      return
    end

    datafiles = Datafile.all
    if datafiles.empty?
      puts "❌ No datafiles found. Run 'bin/setup_local' first to create test fixtures."
      return
    end

    # Generate download records for each year
    (2015..2026).each do |year|
      dataset_count = 0
      file_count = 0

      # Generate dataset download tallies for all datasets
      datasets.each do |dataset|
        # Create downloads throughout the year
        (0..364).step(rand(1..5)).each do |day_offset|
          download_date = Date.new(year, 1, 1) + day_offset.days
          next if download_date.year != year

          DatasetDownloadTally.find_or_create_by!(
            dataset_key: dataset.key,
            doi: dataset.identifier,
            download_date: download_date
          ) do |tally|
            tally.tally = rand(1..10)
          end
          dataset_count += 1
        end
      end

      # Generate datafile download tallies for all datafiles
      datafiles.each do |datafile|
        dataset = datafile.dataset
        next unless dataset

        # Create downloads throughout the year
        (0..364).step(rand(1..5)).each do |day_offset|
          download_date = Date.new(year, 1, 1) + day_offset.days
          next if download_date.year != year

          FileDownloadTally.find_or_create_by!(
            file_web_id: datafile.web_id,
            dataset_key: dataset.key,
            doi: dataset.identifier,
            download_date: download_date
          ) do |tally|
            tally.tally = rand(1..10)
          end
          file_count += 1
        end
      end

      puts "  ✓ Year #{year}: #{dataset_count} dataset downloads, #{file_count} datafile downloads" if dataset_count > 0
    end

    total_dataset_records = DatasetDownloadTally.count
    total_file_records = FileDownloadTally.count
    puts "\n✅ Sample data generation complete!"
    puts "   Total dataset download records: #{total_dataset_records}"
    puts "   Total datafile download records: #{total_file_records}"
  end

  desc "Clear all sample download metrics data (dev and test environments only)"
  task clear_sample_downloads: :environment do
    unless Rails.env.development? || Rails.env.test?
      puts "❌ This task is only for development and test! Current environment: #{Rails.env}"
      return
    end

    puts "🗑️  Clearing all download metrics data...\n"

    dataset_count = DatasetDownloadTally.delete_all
    file_count = FileDownloadTally.delete_all

    puts "✅ Cleared #{dataset_count} dataset download records"
    puts "✅ Cleared #{file_count} datafile download records"
  end

  desc "Regenerate sample data (clear and recreate) - dev and test environments only"
  task regenerate_sample_downloads: :environment do
    unless Rails.env.development? || Rails.env.test?
      puts "❌ This task is only for development and test! Current environment: #{Rails.env}"
      return
    end

    Rake::Task["dev_data:clear_sample_downloads"].invoke
    Rake::Task["dev_data:generate_sample_downloads"].invoke
  end
end
