require 'rake'
require 'json'

namespace :demo do
  desc 'add demo dataset metadata'
  task :add_demo_metadata => :environment do
    demo_json = JSON.parse(File.read("#{Rails.root}/lib/demosets.json"))
    demosetArr = demo_json['demosets']
    demosetArr.each do |demoset|
      dataset = Dataset.new
      dataset.title = demoset['title']
      if demoset['identifier'] && demoset['identifier'] != ''
        dataset.identifier = demoset['identifier']
      end
      dataset.publisher = demoset['publisher']
      dataset.description = demoset['description']
      dataset.license = demoset['license']
      dataset.keywords = demoset['keywords']
      dataset.have_permission = "yes"
      dataset.removed_private = "na"
      dataset.agree = "yes"
      dataset.depositor_name = demoset['depositor_name']
      dataset.depositor_email = demoset['depositor_email']
      if demoset['publication_state'] && demoset['publication_state'] != ''
        dataset.publication_state = demoset['publication_state']
      end
      if demoset['dataset_version'] && demoset['dataset_version'] != ''
        dataset.dataset_version = demoset['dataset_version']
      else
        dataset.version = "1"
      end
      if demoset['is_import'] == true
        dataset.is_import = demoset['is_import']
      else
        dataset.is_import = false
      end
      dataset.save

      creatorsArr = demoset['creators']
      creatorsArr.each do |demo_creator|
        creator = Creator.new(demo_creator)
        creator.dataset_id = dataset.id
        creator.type_of = Databank::CreatorType::PERSON
        creator.save
      end

      fundersArr = demoset['funders']

      if fundersArr
        fundersArr.each do |demo_funder|
          funder = Funder.new(demo_funder)
          funder.dataset_id = dataset.id
          funder.save
        end
      end

      materialsArr = demoset['related_materials']
      if materialsArr
        materialsArr.each do |demo_material|
          material = RelatedMaterial.new(demo_material)
          material.dataset_id = dataset.id
          material.save
        end
      end
      dataset.creators = Creator.where(dataset_id: dataset.id)
      dataset.save
    end
  end
end
