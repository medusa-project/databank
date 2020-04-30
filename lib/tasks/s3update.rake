require 'rake'
namespace :s3update do

  desc 'update database values for medusa_storage'
  task :update4medusa_storage => :environment do
    Dataset.all.each do |dataset|
      #puts(dataset.key)

      dataset.datafiles.each do |datafile|

        if datafile.medusa_path && datafile.medusa_path != ''

          datafile.binary_name = datafile.medusa_path.split("/")[-1]
          datafile.save

          if StorageManager.instance.medusa_root.exist?(datafile.medusa_path)
            datafile.storage_root = 'medusa'
            datafile.storage_key = datafile.medusa_path
            datafile.save
          else
            puts("could not find bytestream for medusa datafile #{datafile.web_id} in dataset #{dataset.key}")
          end

        else
          if datafile.binary && datafile.binary != ""
            datafile.binary_name = datafile.binary
          end

          draft_key = "#{datafile.web_id}/#{datafile.binary_name}"

          unless datafile.storage_root && datafile.storage_root != '' && datafile.storage_key && datafile.storage_key != ''
            if StorageManager.instance.draft_root.exist?(draft_key)
              datafile.storage_root = 'draft'
              datafile.storage_key = draft_key
              datafile.save
            else
              puts("could not find draft bytestream for #{draft_key} in dataset: #{dataset.key}")
            end
          end

        end

      end


    end
  end

end