require 'rake'
require 'json'
require 'fileutils'

namespace :development do
  desc 'add development dataset metadata'
  task :add_development_metadata => :environment do

    local_files_dir = Dir["#{Rails.root}/lib/sample_data/bytestreams/*"]
    local_files_dir.each do |local_file|
      file_parts = local_file.split("/")
      FileUtils.cp(local_file, "#{Rails.root}/storage/minio/databank-local-main/uploads/#{file_parts[-1]}")
    end

    demo_json = JSON.parse(File.read("#{Rails.root}/lib/devsets.json"))
    devsetArr = demo_json['devsets']
    devsetArr.each do |devset|
      dataset = Dataset.new
      dataset.title = devset['title']
      if devset['identifier'] && devset['identifier'] != ''
        dataset.identifier = devset['identifier']
      end
      dataset.publisher = devset['publisher']
      dataset.description = devset['description']
      dataset.license = devset['license']
      dataset.keywords = devset['keywords']
      dataset.have_permission = "yes"
      dataset.removed_private = "na"
      dataset.agree = "yes"
      dataset.depositor_name = devset['depositor_name']
      dataset.depositor_email = devset['depositor_email']
      if devset['publication_state'] && devset['publication_state'] != ''
        dataset.publication_state = devset['publication_state']
      end
      if devset['dataset_version'] && devset['dataset_version'] != ''
        dataset.dataset_version = devset['dataset_version']
      else
        dataset.dataset_version = "1"
      end
      if devset['is_import'] == true
        dataset.is_import = devset['is_import']
      else
        dataset.is_import = false
      end
      dataset.save

      creatorsArr = devset['creators']
      creatorsArr.each do |demo_creator|
        creator = Creator.new(demo_creator)
        creator.dataset_id = dataset.id
        creator.type_of = Databank::CreatorType::PERSON
        creator.save
      end

      fundersArr = devset['funders']

      if fundersArr
        fundersArr.each do |dev_funder|
          funder = Funder.new(dev_funder)
          funder.dataset_id = dataset.id
          funder.save
        end
      end

      materialsArr = devset['related_materials']
      if materialsArr
        materialsArr.each do |dev_material|
          material = RelatedMaterial.new(dev_material)
          material.dataset_id = dataset.id
          material.save
        end
      end
      dataset.creators = Creator.where(dataset_id: dataset.id)
      dataset.save

      datafileArr = devset['datafiles']
      if datafileArr
        datafileArr.each do |dev_datafile|
          df = Datafile.create(dataset_id:   dataset.id,
                               binary_name:  dev_datafile['binary_name'],
                               storage_root: dev_datafile['storage_root'],
                               storage_key:  dev_datafile['storage_key'],
                               mime_type:    dev_datafile['mime_type'],
                               peek_type:    Databank::PeekType::NONE)
          df.binary_size = StorageManager.instance.draft_root.size(df.storage_key)
          df.save

          df.handle_peek

        end
      end
    end

    Dataset.index

  end

end