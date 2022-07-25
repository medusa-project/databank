require 'rake'
require 'json'

namespace :recovery do

  task :restore_record, [:doi] => [:environment] do |t, args|

    event_note = "restoration of #{args[:doi]}"
    if args.has_key?(:note)
      event_note = args[:note]
    end

    event = RestorationEvent.create(note: args[:note])

    serialzation_from_medusa = Dataset.get_serialzation_json_from_medusa(args[:doi])

    Dataset.restore_db_from_serialization(serialzation_from_medusa, event.id)

    # puts restored_dataset.to_yaml

  end

  task :restore_database_from_medusa => :environment do

    event = RestorationEvent.create(note: "full restoration")

    serializations_from_medusa = Dataset.serializations_from_medusa
    serializations_from_medusa.each do |serialization|

      begin
        identifier = nil
        serialization_json = JSON.parse(serialization)
        if serialization_json.has_key?('idb_dataset') && serialization_json['idb_dataset'].has_key?('dataset') && serialization_json['idb_dataset']['dataset'].has_key?('identifier')

          identifier = serialization_json['idb_dataset']['dataset']['identifier']
        else
          raise StandardError.new("no identifier found")
        end

        Dataset.restore_db_from_serialization(serialization, event.id)

        new_dataset = Dataset.find_by_key(serialization_json['idb_dataset']['dataset']['key'])

        #puts new_dataset.full_changelog.to_json

      rescue StandardError => ex
        puts ex.message
      else
        puts "successfully restored #{identifier}"

      end

    end

  end

end