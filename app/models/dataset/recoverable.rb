# frozen_string_literal: true

##
# This module is used to recover datasets from Medusa.
# It is used to recover the serialization and changelog files for a dataset.
# It is used in the Dataset model.

module Dataset::Recoverable
  extend ActiveSupport::Concern

  class_methods do
    def serializations_from_medusa
      directories = Dir.entries(IDB_CONFIG["medusa"]["medusa_path_root"])
      serializations = []

      if directories && directories.length > 2 # more than for . and ..
        directories = directories.select {|directory| directory.to_s.include? "DOI" }

        directories.each do |directory|
          serializations.append(Dataset.get_serialzation_json_from_medusa(directory.gsub("DOI-10-", "10.")))
        end
      end
      serializations
    end

    def get_serialzation_json_from_medusa(identifier)
      # assumes identifier in the format stored in a dataset object
      # rough test: starts with 10.
      raise StandardError.new("missing identifier") unless identifier

      raise StandardError.new("invalid identifier") unless identifier.start_with?("10.")

      dirname = "#{IDB_CONFIG['medusa']['medusa_path_root']}/DOI-#{identifier.parameterize}"

      return %({'status':'error', 'error':"NO DIR: #{dirname}" }) unless Dir.exist? dirname

      sysdir = "#{dirname}/system"
      return %({'status':'error', 'error':"NO SYSDIR: #{sysdir}" }) unless Dir.exist?(sysdir)

      serialization_files = Dir["#{dirname}/system/*"].select {|entry| entry.include? "serialization" }
      return %({'status':'error', 'error':"no serialization: #{dirname}/system" }) if serialization_files.empty?

      # FIRST BRANCH OF HAPPY PATH ENDS HERE
      return IO.read(serialization_files[0]) if serialization_files.length == 1

      date_array = []
      serialization_files.each do |file|
        file_parts = file.split(".")
        timestring = file_parts[1]
        datetime_parts = timestring.split("_")
        date_parts = datetime_parts[0].split("-")
        time_parts = datetime_parts[1].split("-")
        date_array.append(DateTime.new(date_parts[0].to_i, date_parts[1].to_i, date_parts[2].to_i, time_parts[0].to_i, time_parts[1].to_i, 0))
      end
      latest_datetime = date_array.max
      datetime_string = latest_datetime.strftime("%Y-%m-%d_%H-%M")
      latest_serialization_file = "#{dirname}/system/serialization.#{datetime_string}.json"

      # SECOND BRANCH OF HAPPY PATH ENDS HERE
      IO.read(latest_serialization_file)
    end

    def get_changelog_from_medusa(identifier)
      # assumes identifier in the format stored in a dataset object
      # rough test: starts with 10.
      raise StandardError.new("missing identifier") unless identifier

      raise StandardError.new("invalid identifier") unless identifier.start_with?("10.")

      dirname = "#{IDB_CONFIG['medusa']['medusa_path_root']}/DOI-#{identifier.parameterize}"

      return %({'status':'error', 'error':"NO DIR: #{dirname}" }) unless Dir.exist? dirname

      sysdir = "#{dirname}/system"
      return %({'status':'error', 'error':"NO SYSDIR: #{sysdir}" }) unless Dir.exist?(sysdir)

      dirname = "#{IDB_CONFIG['medusa']['medusa_path_root']}/DOI-#{identifier.parameterize}"

      changelog_files = Dir["#{dirname}/system/*"].select {|entry| entry.include? "changelog" }

      return %({'status':'error', 'error':"no changelog files found in: #{dirname}/system" }) if changelog_files.empty?

      # FIRST BRANCH OF HAPPY PATH ENDS HERE
      return IO.read(changelog_files[0]) if changelog_files.length == 1

      date_array = []
      changelog_files.each do |file|
        file_parts = file.split(".")
        timestring = file_parts[1]
        datetime_parts = timestring.split("_")
        date_parts = datetime_parts[0].split("-")
        time_parts = datetime_parts[1].split("-")
        date_array.append(DateTime.new(date_parts[0].to_i, date_parts[1].to_i, date_parts[2].to_i, time_parts[0].to_i, time_parts[1].to_i, 0))
      end
      latest_datetime = date_array.max
      datetime_string = latest_datetime.strftime("%Y-%m-%d_%H-%M")
      latest_changelog_files = "#{dirname}/system/changelog.#{datetime_string}.json"

      # SECOND BRANCH OF HAPPY PATH ENDS HERE
      IO.read(latest_changelog_files)
    end
  end
end
