namespace :globus do
  desc 'copy datasets to globus'
  task :copy_demo_datasets => :environment do
    # start with one demo system dataset
    return unless Rails.env == "demo"
    datasets = Dataset.where(key: 'idbdev-5230909')
    datasets.each do |dataset|
      puts "copying dataset: #{dataset.title}, key: #{dataset.key}"
      dataset.datafiles.each do |datafile|
        puts "copying #{datafile.binary_name}"
        #check if key exists
        next if Application.storage_manager.globus_download_root.exist?("#{dataset.key}/#{datafile.binary_name}")
        puts "does not already exist in the globus download area"
        Application.storage_manager.globus_download_root.copy_content_to("#{dataset.key}/#{datafile.binary_name}",
                                                                         datafile.current_root,
                                                                         datafile.storage_key)
      end
    end
  end
end