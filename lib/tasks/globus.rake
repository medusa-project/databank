namespace :globus do
  desc 'copy datasets to globus'
  task :copy_demo_datasets => :environment do
    # start with one demo system dataset
    return unless Rails.env == "demo"
    datasets = Dataset.where(publication_state: Databank::PublicationState::RELEASED)
    datasets.each do |dataset|
      puts "copying dataset: #{dataset.title}, key: #{dataset.key}"
      dataset.datafiles.each do |datafile|
        #check if key exists
        next if Application.storage_manager.globus_download_root.exist?("#{dataset.key}/#{datafile.binary_name}")
        puts "copying #{datafile.binary_name}"
        Application.storage_manager.globus_download_root.copy_content_to("#{dataset.key}/#{datafile.binary_name}",
                                                                         datafile.current_root,
                                                                         datafile.storage_key)
      end
    end
  end

  task :copy_prod_datasets => :environment do
    # start with one demo system dataset
    return unless Rails.env == "production"
    datasets = Dataset.where(publication_state: Databank::PublicationState::RELEASED)
    datasets.each do |dataset|
      puts "copying dataset: #{dataset.title}, key: #{dataset.key}"
      datasets.each do |dataset|
        puts "copying dataset: #{dataset.title}, key: #{dataset.key}"
        dataset.datafiles.each do |datafile|
          #check if key exists
          next if Application.storage_manager.globus_download_root.exist?("#{dataset.key}/#{datafile.binary_name}")
          puts "copying #{datafile.binary_name}"
          Application.storage_manager.globus_download_root.copy_content_to("#{dataset.key}/#{datafile.binary_name}",
                                                                           datafile.current_root,
                                                                           datafile.storage_key)
        end
      end
    end
  end
end
