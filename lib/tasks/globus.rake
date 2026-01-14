# frozen_string_literal: true

namespace :globus do
  desc "copy datasets to globus"
  task copy_datasets: :environment do 
    datasets = Dataset.select(&:files_public?)
    datasets.each do |dataset|
      # puts "copying dataset: #{dataset.title}, key: #{dataset.key}"
      dataset.datafiles.each do |datafile|
        globus_storage_key = "#{dataset.key}/#{datafile.binary_name}"
        if StorageManager.instance.globus_download_root.exist?(globus_storage_key)
          datafile.update(in_globus: true) if !datafile.in_globus
          next
        end
        StorageManager.instance.globus_download_root.copy_content_to(globus_storage_key,
                                                                     datafile.current_root,
                                                                     datafile.storage_key)
        # update in_globus field of datafile record to true if copy successful
        datafile.update(in_globus: true) if StorageManager.instance.globus_download_root.exist?(globus_storage_key)
      rescue Aws::S3::Errors::NotFound
        # puts "datafile not found: #{datafile.storage_key} in #{datafile.current_root.root_type}"
        next
      end
      # if all datafiles copied successfully, update dataset's all_globus field to true
      if dataset.datafiles.all? { |df| df.in_globus }
        dataset.update(all_globus: true) if !dataset.all_globus
      end
    end
  end
end
