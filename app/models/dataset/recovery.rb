# frozen_string_literal: true

module Dataset::Recovery
  extend ActiveSupport::Concern

  class_methods do
    def serializations_from_medusa

      directories = Dir.entries(IDB_CONFIG['medusa']['medusa_path_root'])
      serializations = Array.new

      if directories && directories.length > 2 # more than for . and ..
        directories = directories.select { |directory| directory.to_s.include? "DOI" }

        directories.each do |directory|
          serializations.append(Dataset.get_serialzation_json_from_medusa(directory.gsub("DOI-10-", "10.")))
        end
      end
      return serializations
    end

    def get_serialzation_json_from_medusa(identifier)

      # assumes identifier in the format stored in a dataset object
      # rough test: starts with 10.

      dirname = nil
      if identifier.start_with?('10.')
        dirname = "#{IDB_CONFIG['medusa']['medusa_path_root']}/DOI-#{identifier.parameterize}"

        if Dir.exists? dirname
          if Dir.exists?("#{dirname}/system")
            serialization_files = Dir["#{dirname}/system/*"].select { |entry| entry.include? "serialization" }

            if serialization_files.length > 0

              if serialization_files.length == 1
                # FIRST BRANCH OF HAPPY PATH ENDS HERE
                return IO.read(serialization_files[0])
              else

                date_array = Array.new
                serialization_files.each do |file|
                  file_parts = file.split(".")
                  timestring = file_parts[1]
                  datetime_parts = timestring.split("_")
                  date_parts = datetime_parts[0].split("-")
                  time_parts = datetime_parts[1].split("-")
                  date_array.append(DateTime.new(date_parts[0].to_i, date_parts[1].to_i, date_parts[2].to_i, time_parts[0].to_i, time_parts[1].to_i, 0))
                end
                latest_datetime = date_array.max
                datetime_string = latest_datetime.strftime('%Y-%m-%d_%H-%M')
                latest_serialization_file = "#{dirname}/system/serialization.#{datetime_string}.json"

                # SECOND BRANCH OF HAPPY PATH ENDS HERE
                return IO.read(latest_serialization_file)

              end


            else
              return %Q[{'status':'error', 'error':"no serialization files found in: #{dirname}/system" }]

            end
          else
            return %Q[{'status':'error', 'error':"DIRECTORY NOT FOUND: #{dirname}/system" }]
          end

        else
          return %Q[{'status':'error', 'error':"DIRECTORY NOT FOUND: #{dirname}" }]
        end

      else
        raise("invalid identifier")
      end

      return %Q[{'status':'error', 'error':'unexpected error'}]

    end

    def get_changelog_from_medusa(identifier)
      # assumes identifier in the format stored in a dataset object
      # rough test: starts with 10.

      raise("missing identifier") unless identifier

      dirname = nil
      if identifier.start_with?('10.')
        dirname = "#{IDB_CONFIG['medusa']['medusa_path_root']}/DOI-#{identifier.parameterize}"

        if Dir.exists? dirname
          if Dir.exists?("#{dirname}/system")
            changelog_files = Dir["#{dirname}/system/*"].select { |entry| entry.include? "changelog" }

            if changelog_files.length > 0

              if changelog_files.length == 1

                # FIRST BRANCH OF HAPPY PATH ENDS HERE
                return IO.read(changelog_files[0])
              else

                date_array = Array.new
                changelog_files.each do |file|
                  file_parts = file.split(".")
                  timestring = file_parts[1]
                  datetime_parts = timestring.split("_")
                  date_parts = datetime_parts[0].split("-")
                  time_parts = datetime_parts[1].split("-")
                  date_array.append(DateTime.new(date_parts[0].to_i, date_parts[1].to_i, date_parts[2].to_i, time_parts[0].to_i, time_parts[1].to_i, 0))
                end
                latest_datetime = date_array.max
                datetime_string = latest_datetime.strftime('%Y-%m-%d_%H-%M')
                latest_changelog_files = "#{dirname}/system/changelog.#{datetime_string}.json"

                # SECOND BRANCH OF HAPPY PATH ENDS HERE
                return IO.read(latest_changelog_files)

              end


            else
              return %Q[{'status':'error', 'error':"no changelog files found in: #{dirname}/system" }]

            end
          else
            return %Q[{'status':'error', 'error':"DIRECTORY NOT FOUND: #{dirname}/system" }]
          end

        else
          return %Q[{'status':'error', 'error':"DIRECTORY NOT FOUND: #{dirname}" }]
        end

      else
        raise("invalid identifier")
      end

      return %Q[{'status':'error', 'error':'unexpected error'}]
    end

  end
end

