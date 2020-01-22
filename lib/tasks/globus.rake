namespace :globus do
  desc 'copy datasets to globus'
  task :copy_demo_datasets => :environment do
    # start with one demo system dataset
    return unless Rails.env == "aws-demo"
    datasets = Dataset.where(key: 'idbdev-5230909')
    datasets.each do |dataset|
      puts "copying dataset: #{dataset.title}, key: #{dataset.key}"
      puts Application.storage_manager.draft_root.name
      puts "draft_root name should be above this."
      puts Application.storage_manager.medusa_root.name
      puts Application.storage_manager.globus_download_root.name
      puts Application.storage_manager.globus_ingest_root.name
      dataset.datafiles.each do |datafile|
        puts "copying #{datafile.binary_name}"
        #check if key exists
        next if Application.storage_manager.globus_download_root.exist?("#{dataset.key}/#{datafile.binary_name}")
        Application.storage_manager.globus_download_root.copy_content_to("#{dataset.key}/#{datafile.binary_name}",
                                                                         datafile.current_root,
                                                                         datafile.storage_key_with_prefix)
      end
    end
  end
end