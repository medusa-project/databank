# frozen_string_literal: true

namespace :globus do
  desc "copy datasets to globus"
  task copy_datasets: :environment do 
    datasets = Dataset.select(&:files_public?)
    datasets.each do |dataset|
      puts "copying dataset: #{dataset.title}, key: #{dataset.key}"
      dataset.datafiles.each do |datafile|
        next if StorageManager.instance.globus_download_root.exist?("#{dataset.key}/#{datafile.binary_name}")

        puts "copying #{datafile.binary_name}"
        StorageManager.instance.globus_download_root.copy_content_to("#{dataset.key}/#{datafile.binary_name}",
                                                                     datafile.current_root,
                                                                     datafile.storage_key)
      rescue Aws::S3::Errors::NotFound
        puts "datafile #{datafile.web_id} not found"
        next
      end
    end
  end
end
