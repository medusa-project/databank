# frozen_string_literal: true

namespace :globus do
  desc "copy datasets to globus (set GLOBUS_VERBOSE=true for progress and diagnostic output)"
  task copy_datasets: :environment do
    verbose = ENV["GLOBUS_VERBOSE"].to_s.match?(/\A(?:1|true|yes|on)\z/i)
    output = ->(message) { puts message if verbose }
    destination_root = StorageManager.instance.globus_download_root
    storage_location = lambda do |root, key|
      if root.root_type == :s3
        "root=#{root.name.inspect} s3://#{root.bucket}/#{root.s3_object(key).key}"
      else
        "root=#{root.name.inspect} type=#{root.root_type} key=#{key.inspect}"
      end
    end
    datasets = Dataset.select(&:files_public?)
    datasets.each do |dataset|
      output.call("copying dataset: #{dataset.title}, key: #{dataset.key}")
      dataset.datafiles.each do |datafile|
        operation = "resolving storage locations"
        context = "dataset=#{dataset.key.inspect} datafile_id=#{datafile.id} " \
                  "web_id=#{datafile.web_id.inspect} filename=#{datafile.binary_name.inspect} " \
                  "storage_root=#{datafile.storage_root.inspect} storage_key=#{datafile.storage_key.inspect}"
        source_root = datafile.current_root
        globus_storage_key = "#{dataset.key}/#{datafile.binary_name}"
        context += "\n  source: #{storage_location.call(source_root, datafile.storage_key)}" \
                   "\n  destination: #{storage_location.call(destination_root, globus_storage_key)}"
        operation = "checking destination before copy"
        if destination_root.exist?(globus_storage_key)
          operation = "updating file Globus flag"
          datafile.update(in_globus: true) if !datafile.in_globus
          next
        end
        operation = "copying source to destination"
        destination_root.copy_content_to(globus_storage_key, source_root, datafile.storage_key)
        # update in_globus field of datafile record to true if copy successful
        operation = "checking destination after copy"
        if destination_root.exist?(globus_storage_key)
          operation = "updating file Globus flag"
          datafile.update(in_globus: true) if !datafile.in_globus
        else
          output.call("WARNING: destination absent after copy\n  #{context}")
        end
      rescue Aws::S3::Errors::NotFound => e
        output.call("WARNING: S3 NotFound while #{operation}; skipping file\n  #{context}\n  #{e.class}: #{e.message}")
        output.call("  A copy-time 404 does not identify which storage request failed; verify both locations.")
        next
      rescue StandardError => e
        output.call("ERROR: failed while #{operation}; stopping task\n  #{context}\n  #{e.class}: #{e.message}")
        raise
      end
      # if all datafiles copied successfully, update dataset's all_globus field to true
      if dataset.datafiles.all? { |df| df.in_globus }
        dataset.update(all_globus: true) if !dataset.all_globus
      end
    end
  end
end
