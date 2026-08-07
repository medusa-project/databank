# frozen_string_literal: true

require "tempfile"

##
# Encapsulates handling reports offered on the metrics page.

class Metric
  LOCK_KEYS = [:dataset_downloads_csv, :datafile_downloads_csv, :dataset_downloads_csv_cal, 
               :dataset_downloads_csv_fis, :datafile_downloads_csv_cal, :datafile_downloads_csv_fis,
               :datasets_tsv, :datafiles_csv, :container_contents_csv, :funders_csv, :related_materials_csv].freeze
  MIMETYPE_DEFAULT = "application/octet-stream"
  DATASETS_TSV_HEADINGS = ["doi", "ingest_date", "release_date", "num_files", "num_bytes", "total_downloads",
                           "num_relationships", "num_creators", "subject", "citation_text"].freeze
  CONTAINER_CONTENTS_CSV_HEADINGS = ["doi", "container_filename", "content_filepath", "content_filename",
                                     "file_format"].freeze
  RELATED_MATERIALS_CSV_HEADINGS = ["doi", "datacite_relationship", "material_id_type", "material_id",
                                    "material_type"].freeze
  VERSION_RELATIONSHIPS = ["IsPreviousVersionOf", "IsNewVersionOf"].freeze
  DATASET_REPORT_CSV_HEADINGS = ["key", "doi", "release_date", "funders", "title", "keywords",
                                 "corresponding_creator", "subject"].freeze
  FIRST_DOWNLOAD_CALENDAR_YEAR = 2016
  FIRST_DOWNLOAD_FISCAL_YEAR = 16
  FISCAL_YEAR_START_MONTH = 7
  DATASET_DOWNLOADS_CSV_HEADINGS = ["dataset_key", "doi", "download_date", "tally"].freeze
  DATAFILE_DOWNLOADS_CSV_HEADINGS = ["file_web_id", "dataset_key", "doi", "download_date", "tally"].freeze
  DOWNLOAD_ZIP_GROUPS = %i[dataset_calendar dataset_fiscal datafile_calendar datafile_fiscal].freeze

  Definition = Struct.new(:key, :config, keyword_init: true) do
    def label
      value = config[:label] || config["label"]
      return value if value

      key.to_s.tr("_", " ")
    end

    def relative_path
      config[:relative_path] || config["relative_path"]
    end

    def download_path
      path = config[:download_path] || config["download_path"]
      return path if path

      absolute = relative_path.to_s
      root_prefix = Rails.root.to_s
      return absolute.delete_prefix(root_prefix) if absolute.start_with?(root_prefix)

      "/#{File.basename(absolute)}"
    end

    def content_type
      value = config[:content_type] || config["content_type"]
      return value if value

      case File.extname(relative_path.to_s)
      when ".json"
        "application/json"
      when ".csv"
        "text/csv"
      when ".tsv"
        "text/tab-separated-values"
      when ".txt"
        "text/plain"
      else
        "application/octet-stream"
      end
    end

    def summary
      config[:summary] || config["summary"]
    end

    def description_blocks
      value = config[:description_blocks] || config["description_blocks"]
      return [] unless value

      value
    end

    def columns
      value = config[:columns] || config["columns"]
      return [] unless value

      value
    end

    def help_url
      config[:help_url] || config["help_url"]
    end

    def show_in_admin?
      return config[:show_in_admin] unless config[:show_in_admin].nil?
      return config["show_in_admin"] unless config["show_in_admin"].nil?

      refreshable?
    end

    def lock_path
      "#{relative_path}.lock"
    end

    def refreshable?
      return config[:refreshable] unless config[:refreshable].nil?
      return config["refreshable"] unless config["refreshable"].nil?

      Metric::LOCK_KEYS.include?(key)
    end

    def writer_method
      method = config[:write_method] || config["write_method"]
      return method.to_sym if method

      "write_#{key}".to_sym
    end

    def display_name
      label
    end

    def in_progress?
      File.exist?(lock_path)
    end

    def mark_in_progress
      FileUtils.touch(lock_path)
    end

    def clear_in_progress
      File.delete(lock_path) if File.exist?(lock_path)
    end
  end

  class << self
    ##
    # refresh all refreshable metrics
    def refresh_metrics
      refreshable_definitions.each do |definition|
        public_send(writer_method_for(definition.key))
      end
    end

    ##
    # Ensure that all required download metrics are present
    # Generate them if and only if they do not already exist
    # Or, for the current one, if it is outdated
    # Outdated for the current calendar or fiscal year means more than one day old
    # Verifies that prior year metrics exist in storage; raises and emails error if missing
    # This is run on deploy and nightly
    #
    # YEAR BOUNDARY HANDLING:
    # - At calendar year boundary (Dec 31 → Jan 1), current_calendar_year increments
    #   Next call detects missing current year file and generates it
    # - At fiscal year boundary (June 30 → July 1), current_fiscal_year increments
    #   Next call detects missing current fiscal year file and generates it
    # - Current year metrics stay in public/ and are refreshed if >1 day old
    # - Prior year metrics are archived to S3 immediately upon generation (see handle_archived_metric)
    def ensure_download_metrics
      begin
        current_cal_year = current_calendar_year
        current_fis_year = current_fiscal_year

        # Check and generate/refresh both dataset and datafile downloads for current years
        [:dataset_downloads, :datafile_downloads].each do |metric_type|
          [:calendar, :fiscal].each do |slice_type|
            year = slice_type == :calendar ? current_cal_year : current_fis_year
            filename = filename_for_year_metric(metric_type, year, slice_type)
            path = File.join(Rails.root, "public", filename)

            # Create if missing or refresh if older than 1 day
            if !File.exist?(path) || (File.mtime(path) < 1.day.ago)
              writer_method = "write_#{metric_type}_csv_by_year"
              public_send(writer_method, year, slice_type)
            end
          end
        end

        # Verify prior year metrics exist in S3 storage (production only)
        # In development/test environments, S3 may not be fully configured
        verify_prior_year_metrics_exist(current_cal_year, current_fis_year) if Rails.env.production?
      rescue StandardError => e
        error_message = "Error in ensure_download_metrics: #{e.message}\n#{e.backtrace.join("\n")}"
        Rails.logger.error(error_message)
        DatabankMailer.error(error_message).deliver_later
        raise
      end
    end

    ##
    # Verify that prior year download metrics exist in S3 storage
    # Raises StandardError if any prior year metrics are missing
    # @param current_cal_year [Integer] current calendar year
    # @param current_fis_year [Integer] current fiscal year (2-digit)
    # @return [void]
    def verify_prior_year_metrics_exist(current_cal_year, current_fis_year)
      missing_metrics = []
      report_root = StorageManager.instance.report_root

      [:dataset_downloads, :datafile_downloads].each do |metric_type|
        # Check prior calendar years
        (FIRST_DOWNLOAD_CALENDAR_YEAR...current_cal_year).each do |year|
          storage_key = storage_key_for_archived_metric(metric_type, year, :calendar)
          missing_metrics << "#{metric_type}_#{year}_calendar" unless report_root.exist?(storage_key)
        end

        # Check prior fiscal years (FY16 onwards)
        (FIRST_DOWNLOAD_FISCAL_YEAR...current_fis_year).each do |fy|
          storage_key = storage_key_for_archived_metric(metric_type, fy, :fiscal)
          missing_metrics << "#{metric_type}_FY#{format('%02d', fy)}_fiscal" unless report_root.exist?(storage_key)
        end
      end

      raise StandardError, "Missing download metrics: #{missing_metrics.join(', ')}" if missing_metrics.any?
    end

    # ========== YEAR CALCULATION & NAMING UTILITIES ==========
    ##
    # @return [Integer] current calendar year
    # Example: 2026 on any day in 2026
    def current_calendar_year
      Time.zone.now.year
    end

    ##
    # @return [Integer] current fiscal year (FY format: last 2 digits of fiscal year end)
    # Fiscal year starts on FISCAL_YEAR_START_MONTH (July)
    # Example: If today is 2026-07-28, FY is 27 (July 2026 - June 2027)
    #          If today is 2026-06-28, FY is 26 (July 2025 - June 2026)
    # This method crosses the calendar year boundary on July 1:
    #   - June 30, 2026 at 23:59 → FY is 26
    #   - July 1, 2026 at 00:00 → FY is 27
    def current_fiscal_year
      now = Time.zone.now
      if now.month >= FISCAL_YEAR_START_MONTH
        (now.year + 1) % 100
      else
        now.year % 100
      end
    end

    ##
    # @param download_date [Date] the download date
    # @return [Hash] with :calendar_year and :fiscal_year for the given date
    def year_slices_for_date(download_date)
      cal_year = download_date.year
      fis_year = if download_date.month >= FISCAL_YEAR_START_MONTH
                   (download_date.year + 1) % 100
                 else
                   download_date.year % 100
                 end
      { calendar_year: cal_year, fiscal_year: fis_year }
    end

    ##
    # @param year [Integer] calendar year or fiscal year (2-digit)
    # @param slice_type [Symbol] :calendar or :fiscal
    # @return [Boolean] true if the year is current
    def year_is_current?(year, slice_type)
      case slice_type
      when :calendar
        year == current_calendar_year
      when :fiscal
        year == current_fiscal_year
      else
        raise ArgumentError, "Invalid slice_type: #{slice_type}"
      end
    end

    ##
    # @param metric_type [Symbol] :dataset_downloads or :datafile_downloads
    # @param year [Integer] calendar year (4-digit) or fiscal year (2-digit)
    # @param slice_type [Symbol] :calendar or :fiscal
    # @return [String] filename like "dataset_downloads_2026.csv" or "datafile_downloads_FY26.csv"
    def filename_for_year_metric(metric_type, year, slice_type)
      base = metric_type.to_s
      year_suffix = slice_type == :fiscal ? "FY#{year.to_s.rjust(2, '0')}" : year.to_s
      "#{base}_#{year_suffix}.csv"
    end

    ##
    # @param metric_type [Symbol] :dataset_downloads or :datafile_downloads
    # @param year [Integer] calendar year (4-digit) or fiscal year (2-digit)
    # @param slice_type [Symbol] :calendar or :fiscal
    # @return [String] storage key for archived metrics in S3 (same as filename)
    def storage_key_for_archived_metric(metric_type, year, slice_type)
      filename_for_year_metric(metric_type, year, slice_type)
    end

    ##
    # @param fiscal_year [Integer] 2-digit fiscal year end (e.g., 27 for FY27)
    # @return [Array<Date>] [start_date, end_date] for the fiscal year
    # FY27 = July 2026 - June 2027
    def date_range_for_fiscal_year(fiscal_year)
      # Assume 21st century
      start_year = 2000 + fiscal_year - 1
      start_date = Date.new(start_year, FISCAL_YEAR_START_MONTH, 1)
      end_date = Date.new(start_year + 1, FISCAL_YEAR_START_MONTH, 1) - 1.day
      [start_date, end_date]
    end

    # ========== END YEAR UTILITIES ==========

    ##
    # @param metric_key [Symbol] key from METRICS_CONFIG
    # @return [String] path to the lock file for the given metric
    def lock_path(metric_key)
      definition_for(metric_key).lock_path
    end

    ##
    # @param metric_key [Symbol] key from METRICS_CONFIG
    # @return [Boolean] true if a refresh is currently in progress for this metric
    def in_progress?(metric_key)
      definition_for(metric_key).in_progress?
    end

    ##
    # @return [Hash] map of metric_key => Boolean indicating in-progress state for each metric
    def refresh_status
      refreshable_definitions.each_with_object({}) do |definition, statuses|
        statuses[definition.key] = definition.in_progress?
      end
    end

    ##
    # Create the lock file for the given metric key.
    # @param metric_key [Symbol]
    def mark_in_progress(metric_key)
      definition_for(metric_key).mark_in_progress
    end

    ##
    # Remove the lock file for the given metric key.
    # @param metric_key [Symbol]
    def clear_in_progress(metric_key)
      definition_for(metric_key).clear_in_progress
    end

    ##
    # @return [Hash] the modified times of the metrics
    def modified_times
      refreshable_definitions.each do |definition|
        ensure_metric_file_present(definition)
      end

      refreshable_definitions.each_with_object({}) do |definition, hash|
        hash[definition.key] = File.mtime(definition.relative_path).strftime("%B %d, %Y %I:%M %P %Z")
      end
    end

    def definitions
      METRICS_CONFIG.each_with_object([]) do |(raw_key, raw_config), arr|
        metric_key = raw_key.to_sym
        metric_config = raw_config.respond_to?(:to_h) ? raw_config.to_h : {}
        arr << Definition.new(key: metric_key, config: metric_config)
      end
    end

    def definition_for(metric_key)
      normalized_key = metric_key.to_sym
      definition = definitions.find {|item| item.key == normalized_key }
      raise ArgumentError, "Unknown metric key: #{metric_key}" unless definition

      definition
    end

    def refreshable_definitions
      definitions.select(&:refreshable?).sort_by do |definition|
        LOCK_KEYS.index(definition.key) || LOCK_KEYS.length
      end
    end

    def admin_definitions
      definitions.select(&:show_in_admin?).sort_by do |definition|
        LOCK_KEYS.index(definition.key) || LOCK_KEYS.length
      end
    end

    def writer_method_for(metric_key)
      definition = definition_for(metric_key)
      writer_method = definition.writer_method
      return writer_method if respond_to?(writer_method)

      raise ArgumentError, "No writer method found for metric key: #{metric_key}"
    end

    def ensure_metric_file_present(definition)
      return if File.exist?(definition.relative_path)

      public_send(writer_method_for(definition.key))
      return if File.exist?(definition.relative_path)

      raise StandardError, "unable to create #{definition.display_name}"
    end

    def ensure_fresh_metrics
      current_modified_times = modified_times
      # if any metric is more than a day old, refresh it
      refreshable_definitions.each do |definition|
        next unless definition.refreshable?

        modified_time = current_modified_times[definition.key]
        next unless modified_time

        public_send(writer_method_for(definition.key)) if Time.zone.parse(modified_time) < 1.day.ago
      end
    end

    ##
    # write the dataset downloads csv
    # Processes tallies in batches to limit memory usage.
    # @deprecated Use write_dataset_downloads_csv_orchestrator instead (writes both calendar and fiscal years)
    # @return [void]
    def write_dataset_downloads_csv
      Rails.logger.warn("DEPRECATED: write_dataset_downloads_csv called. Use write_dataset_downloads_csv_orchestrator instead.")
      write_dataset_downloads_csv_orchestrator
    end

    ##
    # write the datafile downloads csv
    # Processes tallies in batches to limit memory usage.
    # @deprecated Use write_datafile_downloads_csv_orchestrator instead (writes both calendar and fiscal years)
    # @return [void]
    def write_datafile_downloads_csv
      Rails.logger.warn("DEPRECATED: write_datafile_downloads_csv called. Use write_datafile_downloads_csv_orchestrator instead.")
      write_datafile_downloads_csv_orchestrator
    end

    # ========== YEAR-SLICED DOWNLOAD METRICS ==========

    ##
    # Lock/unlock methods for year-specific metrics (not in METRICS_CONFIG)
    def year_metric_lock_path(metric_type, year, slice_type)
      filename = filename_for_year_metric(metric_type, year, slice_type)
      File.join(Rails.root, "public", "#{filename}.lock")
    end

    def mark_year_metric_in_progress(metric_type, year, slice_type)
      FileUtils.touch(year_metric_lock_path(metric_type, year, slice_type))
    end

    def clear_year_metric_in_progress(metric_type, year, slice_type)
      lock_path = year_metric_lock_path(metric_type, year, slice_type)
      File.delete(lock_path) if File.exist?(lock_path)
    end

    ##
    # write the dataset downloads csv for a specific year/slice
    # Filters DatasetDownloadTally by calendar or fiscal year and writes to versioned file
    # @param year [Integer] calendar year (4-digit) or fiscal year (2-digit)
    # @param slice_type [Symbol] :calendar or :fiscal
    # @return [void]
    #
    # YEAR BOUNDARY FLOW:
    # 1. Current year (e.g., 2026): File written to public/, stays there, refreshed daily
    # 2. Prior year (e.g., 2025 when called in 2026): File written to temp, immediately archived to S3, deleted from public/
    # 3. This ensures public/ only contains current year metrics; prior years live in S3
    def write_dataset_downloads_csv_by_year(year, slice_type)
      target_filename = filename_for_year_metric(:dataset_downloads, year, slice_type)
      target_path = File.join(Rails.root, "public", target_filename)

      mark_year_metric_in_progress(:dataset_downloads, year, slice_type)
      begin
        batch_size = IDB_CONFIG[:batch_size] || 500
        write_metric_files_atomically(target_path) do |temp_paths|
          CSV.open(temp_paths[target_path], "w") do |report|
            report << DATASET_DOWNLOADS_CSV_HEADINGS

            public_keys = metadata_public_dataset_keys
            query = DatasetDownloadTally.where(dataset_key: public_keys)
            query = if slice_type == :calendar
                      query.where("EXTRACT(YEAR FROM download_date) = ?", year)
                    else
                      start_date, end_date = date_range_for_fiscal_year(year)
                      query.where("download_date >= ? AND download_date <= ?", start_date, end_date)
                    end

            query.find_in_batches(batch_size: batch_size) do |batch|
              batch.each do |row|
                report << [row.dataset_key, row.doi, row.download_date, row.tally]
              end
            end
          end
        end
        # Handle archival of non-current year files to storage
        handle_archived_metric(target_path, :dataset_downloads, year, slice_type)
      ensure
        clear_year_metric_in_progress(:dataset_downloads, year, slice_type)
      end
    end

    ##
    # write the datafile downloads csv for a specific year/slice
    # Filters FileDownloadTally by calendar or fiscal year and writes to versioned file
    # @param year [Integer] calendar year (4-digit) or fiscal year (2-digit)
    # @param slice_type [Symbol] :calendar or :fiscal
    # @return [void]
    def write_datafile_downloads_csv_by_year(year, slice_type)
      target_filename = filename_for_year_metric(:datafile_downloads, year, slice_type)
      target_path = File.join(Rails.root, "public", target_filename)

      mark_year_metric_in_progress(:datafile_downloads, year, slice_type)
      begin
        batch_size = IDB_CONFIG[:batch_size] || 500
        write_metric_files_atomically(target_path) do |temp_paths|
          CSV.open(temp_paths[target_path], "w") do |report|
            report << DATAFILE_DOWNLOADS_CSV_HEADINGS

            public_keys = metadata_public_dataset_keys
            query = FileDownloadTally.where(dataset_key: public_keys)
            query = if slice_type == :calendar
                      query.where("EXTRACT(YEAR FROM download_date) = ?", year)
                    else
                      start_date, end_date = date_range_for_fiscal_year(year)
                      query.where("download_date >= ? AND download_date <= ?", start_date, end_date)
                    end

            query.find_in_batches(batch_size: batch_size) do |batch|
              batch.each do |row|
                report << [row.file_web_id, row.dataset_key, row.doi, row.download_date, row.tally]
              end
            end
          end
        end
        # Handle archival of non-current year files to storage
        handle_archived_metric(target_path, :datafile_downloads, year, slice_type)
      ensure
        clear_year_metric_in_progress(:datafile_downloads, year, slice_type)
      end
    end

    ##
    # Orchestrator: write dataset downloads for current calendar and fiscal years
    # @return [void]
    def write_dataset_downloads_csv_orchestrator
      write_dataset_downloads_csv_by_year(current_calendar_year, :calendar)
      write_dataset_downloads_csv_by_year(current_fiscal_year, :fiscal)
    end

    ##
    # Orchestrator: write datafile downloads for current calendar and fiscal years
    # @return [void]
    def write_datafile_downloads_csv_orchestrator
      write_datafile_downloads_csv_by_year(current_calendar_year, :calendar)
      write_datafile_downloads_csv_by_year(current_fiscal_year, :fiscal)
    end

    # ========== END YEAR-SLICED DOWNLOAD METRICS ==========

    # ========== ARCHIVE/STORAGE LOGIC ==========
    #
    # YEAR BOUNDARY ARCHIVAL MECHANISM:
    # When a year transitions (e.g., calendar 2025 → 2026, or fiscal FY25 → FY26):
    #   - ensure_download_metrics detects new current year file is missing
    #   - Calls write_*_by_year(new_year, slice_type)
    #   - File is created in public/
    #   - handle_archived_metric checks: is this year current? NO (we just changed years)
    #   - Immediately archives the old year file to S3 and deletes from public/
    #   - Result: seamless transition where only current year stays in public/
    #
    # Example timeline for calendar year boundary (Dec 31, 2025 → Jan 1, 2026):
    #   Dec 31 23:59 - current_calendar_year = 2025, public/dataset_downloads_2025.csv exists
    #   Jan 1 00:00 - current_calendar_year = 2026
    #   Jan 1 cron  - ensure_download_metrics runs:
    #     - Detects public/dataset_downloads_2026.csv missing
    #     - Calls write_dataset_downloads_csv_by_year(2026, :calendar)
    #     - Writes 2026 data to public/dataset_downloads_2026.csv
    #     - should_archive_metric?(2026, :calendar) = false (2026 is current), stays in public/
    #     - Old 2025 file archived via separate rake task or next occurrence of its write

    ##
    # Determine if a metric for the given year/slice should be archived
    # Current years stay in public/, prior years move to storage
    # @param year [Integer] calendar year (4-digit) or fiscal year (2-digit)
    # @param slice_type [Symbol] :calendar or :fiscal
    # @return [Boolean] true if the metric is no longer current and should be archived
    def should_archive_metric?(year, slice_type)
      !year_is_current?(year, slice_type)
    end

    ##
    # Archive a metric file from public/ to S3 storage via StorageManager
    # After upload, deletes the local file
    # @param file_path [String] absolute path to the file to archive
    # @param metric_type [Symbol] :dataset_downloads or :datafile_downloads
    # @param year [Integer] calendar year (4-digit) or fiscal year (2-digit)
    # @param slice_type [Symbol] :calendar or :fiscal
    # @return [String] the storage key under report_root
    def archive_metric_to_storage(file_path, metric_type, year, slice_type)
      return nil unless File.exist?(file_path)

      storage_key = storage_key_for_archived_metric(metric_type, year, slice_type)
      report_root = StorageManager.instance.report_root

      # Read file content and upload to storage
      file_content = File.read(file_path)
      file_size = File.size(file_path)
      report_root.copy_io_to(storage_key, StringIO.new(file_content), nil, file_size)

      # Delete local file after successful upload
      File.delete(file_path)

      storage_key
    end

    ##
    # Check if an archived metric exists in S3 storage
    # @param metric_type [Symbol] :dataset_downloads or :datafile_downloads
    # @param year [Integer] calendar year (4-digit) or fiscal year (2-digit)
    # @param slice_type [Symbol] :calendar or :fiscal
    # @return [Boolean] true if the metric file exists in storage
    def archived_metric_exists?(metric_type, year, slice_type)
      storage_key = storage_key_for_archived_metric(metric_type, year, slice_type)
      report_root = StorageManager.instance.report_root
      report_root.exist?(storage_key)
    rescue => e
      Rails.logger.error("Error checking archived metric #{storage_key}: #{e.message}")
      false
    end

    ##
    # Retrieve an archived metric from S3 storage
    # @param metric_type [Symbol] :dataset_downloads or :datafile_downloads
    # @param year [Integer] calendar year (4-digit) or fiscal year (2-digit)
    # @param slice_type [Symbol] :calendar or :fiscal
    # @return [String, nil] the file content, or nil if not found
    def retrieve_archived_metric_from_storage(metric_type, year, slice_type)
      storage_key = storage_key_for_archived_metric(metric_type, year, slice_type)
      report_root = StorageManager.instance.report_root

      # Use AWS SDK to retrieve file from S3 (same as datafiles and curator reports)
      begin
        expanded_key = "#{report_root.prefix}#{storage_key}"
        object = Application.aws_client.get_object(bucket: report_root.bucket, key: expanded_key)
        object.body.read
      rescue => e
        Rails.logger.error("Error retrieving archived metric #{storage_key}: #{e.message}")
        nil
      end
    end

    ##
    # Handle archival workflow: check if metric should be archived and move to storage if needed
    # Called after successfully writing a metric file
    # This is the KEY method for year boundary transitions
    # @param file_path [String] absolute path to the metric file
    # @param metric_type [Symbol] :dataset_downloads or :datafile_downloads
    # @param year [Integer] calendar year (4-digit) or fiscal year (2-digit)
    # @param slice_type [Symbol] :calendar or :fiscal
    # @return [String, nil] storage key if archived, nil if left in public/
    #
    # Called at end of every write_*_by_year method:
    # - If year is current: file stays in public/ (returns nil)
    # - If year is prior: file immediately moved to S3 and deleted (returns storage key)
    def handle_archived_metric(file_path, metric_type, year, slice_type)
      return nil unless should_archive_metric?(year, slice_type)

      archive_metric_to_storage(file_path, metric_type, year, slice_type)
    end

    # ========== END ARCHIVE/STORAGE LOGIC ==========

    ##
    # Build an in-memory zip containing every CSV for the given group.
    # Current-year file is read from public/; prior years are fetched from S3.
    # @param group [Symbol] one of DOWNLOAD_ZIP_GROUPS
    # @return [String] raw zip binary
    def build_zip_for_group(group)
      raise ArgumentError, "Invalid group: #{group}" unless DOWNLOAD_ZIP_GROUPS.include?(group.to_sym)

      metric_type, slice_type = group.to_s.split("_").then { |m, s| ["#{m}_downloads".to_sym, s.to_sym] }
      current_year = slice_type == :fiscal ? current_fiscal_year : current_calendar_year
      first_year   = slice_type == :fiscal ? FIRST_DOWNLOAD_FISCAL_YEAR : FIRST_DOWNLOAD_CALENDAR_YEAR

      require "zip"
      buffer = Zip::OutputStream.write_buffer do |zip|
        # Current year from public/
        current_filename = filename_for_year_metric(metric_type, current_year, slice_type)
        current_path = Rails.root.join("public", current_filename)
        if File.exist?(current_path)
          zip.put_next_entry(current_filename)
          zip.write(File.read(current_path))
        end

        # Prior years from S3
        prior_range = slice_type == :fiscal ? (first_year...current_year).to_a : (first_year...current_year).to_a
        prior_range.reverse_each do |year|
          content = retrieve_archived_metric_from_storage(metric_type, year, slice_type)
          next unless content.present?

          zip.put_next_entry(filename_for_year_metric(metric_type, year, slice_type))
          zip.write(content)
        end
      end
      buffer.string
    end

    ##
    # Generate all historical download metrics (calendar and fiscal years)
    # Generates dataset and datafile downloads for all years back to FIRST_DOWNLOAD_CALENDAR_YEAR
    # Prior year files are automatically archived to S3 during generation
    # @return [void]
    def generate_all_historical_downloads
      current_cal_year = current_calendar_year
      current_fis_year = current_fiscal_year

      %i[dataset_downloads datafile_downloads].each do |metric_type|
        Rails.logger.info("Generating #{metric_type}...")

        # Generate calendar year metrics
        (FIRST_DOWNLOAD_CALENDAR_YEAR...current_cal_year).each do |year|
          Rails.logger.info("  Generating #{metric_type} for calendar year #{year}...")
          public_send("write_#{metric_type}_csv_by_year", year, :calendar)
        end

        # Generate fiscal year metrics (FY16 onwards)
        (FIRST_DOWNLOAD_FISCAL_YEAR...current_fis_year).each do |fy|
          Rails.logger.info("  Generating #{metric_type} for fiscal year FY#{format('%02d', fy)}...")
          public_send("write_#{metric_type}_csv_by_year", fy, :fiscal)
        end
      end
    end

    ##
    # Archive prior year download metrics from public/ to S3 storage
    # Moves non-current year files to S3 and deletes them from public/
    # @return [void]
    def archive_prior_year_downloads_to_storage
      current_cal_year = current_calendar_year
      current_fis_year = current_fiscal_year

      %i[dataset_downloads datafile_downloads].each do |metric_type|
        # Archive old calendar year files
        previous_cal_year = current_cal_year - 1
        loop do
          filename = filename_for_year_metric(metric_type, previous_cal_year, :calendar)
          file_path = File.join(Rails.root, "public", filename)

          break unless File.exist?(file_path)

          Rails.logger.info("Archiving #{filename}...")
          storage_key = archive_metric_to_storage(file_path, metric_type, previous_cal_year, :calendar)
          Rails.logger.info("  → Stored as: #{storage_key}")

          previous_cal_year -= 1
          break if previous_cal_year < FIRST_DOWNLOAD_CALENDAR_YEAR
        end

        # Archive old fiscal year files
        previous_fis_year = current_fis_year - 1
        loop do
          break if previous_fis_year < FIRST_DOWNLOAD_FISCAL_YEAR

          filename = filename_for_year_metric(metric_type, previous_fis_year, :fiscal)
          file_path = File.join(Rails.root, "public", filename)

          break unless File.exist?(file_path)

          Rails.logger.info("Archiving #{filename}...")
          storage_key = archive_metric_to_storage(file_path, metric_type, previous_fis_year, :fiscal)
          Rails.logger.info("  → Stored as: #{storage_key}")

          previous_fis_year -= 1
        end
      end
    end

    ##
    # write the datasets tsv
    # Processes datasets one at a time via find_each to limit memory usage.
    # @return [void]
    def write_datasets_tsv
      metric_key = :datasets_tsv
      mark_in_progress(metric_key)
      begin
        batch_size = IDB_CONFIG[:batch_size] || 500
        target_path = METRICS_CONFIG[metric_key][:relative_path]
        write_metric_files_atomically(target_path) do |temp_paths|
          File.open(temp_paths[target_path], "w") do |file|
            file.puts DATASETS_TSV_HEADINGS.join("\t")
            Dataset.find_each(batch_size: batch_size) do |dataset|
              next unless dataset.metadata_public?

              dataset.handle_related_materials
              file.puts datasets_tsv_row(dataset).join("\t")
            end
          end
        end
      ensure
        clear_in_progress(metric_key)
      end
    end

    def datasets_tsv_row(dataset)
      [dataset.identifier.to_s,
       dataset.ingest_datetime.to_date.iso8601,
       dataset.release_date.iso8601,
       dataset.datafiles.count,
       dataset.total_filesize,
       dataset.total_downloads,
       dataset.num_external_relationships,
       dataset.creators.count,
       dataset.subject.to_s,
       dataset.plain_text_citation]
    end

    # Returns dataset keys matching the same criteria as metadata_public? — used to
    # filter download tallies so they align with the datasets.tsv export.
    def metadata_public_dataset_keys
      public_states = [Databank::PublicationState::RELEASED,
                       Databank::PublicationState::Embargo::FILE,
                       Databank::PublicationState::TempSuppress::FILE,
                       Databank::PublicationState::PermSuppress::FILE]
      ok_hold_states = [nil,
                        Databank::PublicationState::TempSuppress::NONE,
                        Databank::PublicationState::TempSuppress::FILE,
                        Databank::PublicationState::PermSuppress::FILE]
      Dataset.where(is_test: false,
                    publication_state: public_states,
                    hold_state: ok_hold_states)
             .pluck(:key)
    end

    ##
    # write the datafiles csv
    # Processes datasets in batches; datafiles in batches per dataset.
    # @return [void]
    def write_datafiles_csv
      metric_key = :datafiles_csv
      mark_in_progress(metric_key)
      begin
        batch_size = IDB_CONFIG[:batch_size] || 500
        target_path = METRICS_CONFIG[metric_key][:relative_path]
        write_metric_files_atomically(target_path) do |temp_paths|
          CSV.open(temp_paths[target_path], "w") do |report|
            report << ["doi", "pub_date", "filename", "file_format", "num_bytes"]
            Dataset.find_in_batches(batch_size: batch_size) do |datasets|
              datasets.each do |dataset|
                next unless dataset.metadata_public?

                dataset.datafiles.reorder(nil).find_in_batches(batch_size: batch_size) do |datafiles|
                  write_datafile_csv_batch(report, dataset, datafiles)
                end
              end
            end
          end
        end
      ensure
        clear_in_progress(metric_key)
      end
    end

    ##
    # write the datafile csv datafile batch
    # @param report [CSV] the report writer
    # @param dataset [Dataset] the dataset
    # @param datafiles [Array] the datafiles
    def write_datafile_csv_batch(report, dataset, datafiles)
      return if datafiles.empty?

      datafiles.each do |datafile|
        report << [dataset.identifier.to_s,
                   dataset.release_date.iso8601.to_s,
                   datafile.bytestream_name.to_s,
                   datafile.mime_type || MIMETYPE_DEFAULT,
                   datafile.bytestream_size]
      end
    end

    ##
    # write_container_contents_csv
    # Processes datasets one at a time via find_each to limit memory usage.
    # @return [void]
    def write_container_contents_csv
      metric_key = :container_contents_csv
      mark_in_progress(metric_key)
      begin
        batch_size = IDB_CONFIG[:batch_size] || 500
        target_path = METRICS_CONFIG[metric_key][:relative_path]
        write_metric_files_atomically(target_path) do |temp_paths|
          CSV.open(temp_paths[target_path], "w") do |report|
            report << CONTAINER_CONTENTS_CSV_HEADINGS
            Dataset.find_each(batch_size: batch_size) do |dataset|
              next unless dataset.metadata_public?

              archive_datafiles_relation(dataset).find_each(batch_size: batch_size) do |datafile|
                write_container_contents_rows(report, dataset, datafile)
              end
            end
          end
        end
      ensure
        clear_in_progress(metric_key)
      end
    end

    def archive_datafiles_relation(dataset)
      dataset.datafiles
             .where(peek_type: Databank::PeekType::LISTING)
             .includes(:nested_items)
             .reorder(nil)
    end

    def write_container_contents_rows(report, dataset, datafile)
      datafile.nested_items.each do |item|
        report << [dataset.identifier.to_s,
                   datafile.bytestream_name.to_s,
                   item.item_path,
                   item.item_name,
                   item.media_type]
      end
    end

    ##
    # write_funders_csv
    # Processes datasets one at a time via find_each to limit memory usage.
    # @return [void]
    def write_funders_csv
      metric_key = :funders_csv
      mark_in_progress(metric_key)
      begin
        batch_size = IDB_CONFIG[:batch_size] || 500
        target_path = METRICS_CONFIG[metric_key][:relative_path]
        write_metric_files_atomically(target_path) do |temp_paths|
          CSV.open(temp_paths[target_path], "w") do |report|
            report << ["doi", "funder", "grant"]
            Dataset.find_each(batch_size: batch_size) do |dataset|
              next unless dataset.metadata_public?

              dataset.funders.each do |funder|
                report << [dataset.identifier, funder.name, funder.grant]
              end
            end
          end
        end
      ensure
        clear_in_progress(metric_key)
      end
    end

    ##
    # write_related_materials_csv
    # Processes datasets one at a time via find_each to limit memory usage.
    # @return [void]
    def write_related_materials_csv
      metric_key = :related_materials_csv
      mark_in_progress(metric_key)
      begin
        batch_size = IDB_CONFIG[:batch_size] || 500
        target_path = METRICS_CONFIG[metric_key][:relative_path]
        write_metric_files_atomically(target_path) do |temp_paths|
          CSV.open(temp_paths[target_path], "w") do |report|
            report << RELATED_MATERIALS_CSV_HEADINGS
            Dataset.find_each(batch_size: batch_size) do |dataset|
              next unless dataset.metadata_public?

              dataset.related_materials.each do |material|
                write_related_materials_rows(report, dataset, material)
              end
            end
          end
        end
      ensure
        clear_in_progress(metric_key)
      end
    end

    def write_related_materials_rows(report, dataset, material)
      related_material_relationships(material).each do |relationship|
        report << [dataset.identifier.to_s, relationship.to_s, material.uri_type.to_s, material.uri.to_s,
                   material.selected_type.to_s]
      end
    end

    def related_material_relationships(material)
      (material.datacite_list.presence || "")
        .split(",")
        .reject {|relationship| VERSION_RELATIONSHIPS.include?(relationship) }
    end

    def write_json_array_rows(writer, root_key, relation, batch_size: IDB_CONFIG[:batch_size] || 500)
      first_record = true
      writer.puts %({"#{root_key}":[)
      relation.find_in_batches(batch_size: batch_size) do |batch|
        batch.each do |row|
          row_json = yield(row).to_json
          writer.puts(first_record ? row_json : ",#{row_json}")
          first_record = false
        end
      end
      writer.puts "]}"
    end

    def write_metric_files_atomically(*target_paths) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
      temp_files = target_paths.each_with_object({}) do |target_path, hash|
        extension = File.extname(target_path)
        basename = File.basename(target_path, extension)
        hash[target_path] = Tempfile.new([basename, extension], File.dirname(target_path))
      end

      begin
        yield temp_files.transform_values(&:path)
        temp_files.each_value(&:flush)
        temp_files.each_value(&:close)
        temp_files.each do |target_path, temp_file|
          FileUtils.mv(temp_file.path, target_path)
        end
      ensure
        temp_files.each_value do |temp_file|
          temp_file.close unless temp_file.closed?
          File.delete(temp_file.path) if File.exist?(temp_file.path)
        end
      end
    end

    ##
    # generate_datasets_reports
    # This method writes a dataset report for the most recent version of each dataset with public metadata
    # There are two reports written: a csv and plain text report
    # the csv has everything except the description
    # the plain text report has the description and metadata to connect it to the csv
    # request detail: a report for the Data Bank from beginning to now that includes: DOI, Pub Date, Funder, Title, Keywords, Descriptions, Corresponding Creator, Subject
    # @return [void]
    def generate_datasets_reports
      batch_size = IDB_CONFIG[:batch_size] || 500
      csv_target_path = METRICS_CONFIG[:dataset_report_csv][:relative_path]
      text_target_path = METRICS_CONFIG[:dataset_report_text][:relative_path]
      write_metric_files_atomically(csv_target_path, text_target_path) do |temp_paths|
        File.open(temp_paths[text_target_path], "w") do |text_file|
          CSV.open(temp_paths[csv_target_path], "w", force_quotes: false) do |report|
            report << DATASET_REPORT_CSV_HEADINGS
            Dataset.find_each(batch_size: batch_size) do |dataset|
              next unless include_in_dataset_reports?(dataset)

              report << dataset_report_csv_row(dataset)
              text_file.write(dataset_report_text_block(dataset))
            end
          end
        end
      end
    end

    def include_in_dataset_reports?(dataset)
      dataset.metadata_public? && dataset.is_most_recent_version
    end

    def dataset_report_csv_row(dataset)
      [dataset.key,
       dataset.identifier,
       dataset.release_date.iso8601.to_s,
       dataset_report_funders_value(dataset),
       dataset.title,
       dataset.keywords,
       dataset_report_corresponding_creator_value(dataset),
       dataset.subject]
    end

    def dataset_report_funders_value(dataset)
      return nil unless dataset.funders.any?

      dataset.funders.map {|funder| "#{funder.name} (#{funder.grant})" }.join("; ")
    end

    def dataset_report_corresponding_creator_value(dataset)
      "#{dataset.corresponding_creator_name} | #{dataset.corresponding_creator_email}"
    end

    def dataset_report_text_block(dataset)
      "Key: #{dataset.key}\n" \
        "Citation: #{dataset.plain_text_citation}\n" \
        "Description: #{dataset.description}\n" \
        "----------------------------------------\n\n"
    end
  end
end
