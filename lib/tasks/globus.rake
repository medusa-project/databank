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
        begin
          next if Application.storage_manager.globus_download_root.exist?("#{dataset.key}/#{datafile.binary_name}")
          puts "copying #{datafile.binary_name}"
          Application.storage_manager.globus_download_root.copy_content_to("#{dataset.key}/#{datafile.binary_name}",
                                                                           datafile.current_root,
                                                                           datafile.storage_key)
        rescue Aws::S3::Errors::NotFound
          next
        end

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

  task :test_listing => :environment do

    test_key = "DEMOIDB-0690780"
    raise "files not found on Globus endpoint" unless Application.storage_manager.draft_root.exist?(test_key)
    keys = Application.storage_manager.draft_root.file_keys(test_key)
    keys.each do |key|
      puts key
    end

  end

end
