require 'rake'
require 'open-uri'

namespace :databank do

  namespace :rails_cache do
    desc "Clear Rails cache (sessions, views, etc.)"
    task clear: :environment do
      Rails.cache.clear
    end
  end

  desc 'recover missing dois from file download tally records'
  task :recover_file_download => :environment do
    incomplete_records = FileDownloadTally.where(doi: "")
    incomplete_records.each do |tally|
      dataset = Dataset.find_by_key(tally.dataset_key)
      if dataset

        if dataset.identifier && dataset.identifier != ""
          tally.doi = dataset.identifier
          tally.save
        else
          tally.destroy
        end
      end
    end
  end

  desc 'fill in missing peek info for datafiles'
  task :set_missing_peek_info => :environment do
    datafiles = Datafile.where(peek_type: nil)
    datafiles.each do |datafile|
      self.handle_peek if !datafile.mime_type || datafile.mime_type == ""
    end
  end

  desc 'delete specific dataset'
  task :delete_specific => :environment do

    destroy_me = Dataset.find_by_key('IDBDEV-5368097')
    destroy_me.destroy

  end

  desc 'update sitemap'
  task :update_sitemap => :environment do

    doc = Nokogiri::XML::Document.parse(%Q(<?xml version="1.0"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.sitemaps.org/schemas/sitemap/0.9 http://www.sitemaps.org/schemas/sitemap/0.9/sitemap.xsd"></urlset>))

    resourceNode = doc.first_element_child

    welcomeNode = doc.create_element('url')
    locNode = doc.create_element('loc')
    locNode.content = IDB_CONFIG[:root_url_text]
    locNode.parent = welcomeNode
    welcomeNode.parent = resourceNode

    policiesNode = doc.create_element('url')
    locNode = doc.create_element('loc')
    locNode.content = "#{IDB_CONFIG[:root_url_text]}/policies"
    locNode.parent = policiesNode
    policiesNode.parent = resourceNode


    helpNode = doc.create_element('url')
    locNode = doc.create_element('loc')
    locNode.content = "#{IDB_CONFIG[:root_url_text]}/help"
    locNode.parent = helpNode
    helpNode.parent = resourceNode

    released_datasets = Dataset.where(:publication_state => Databank::PublicationState::RELEASED )

    released_datasets.each do |dataset|
      urlNode = doc.create_element('url')

      locNode = doc.create_element('loc')
      locNode.content = "#{IDB_CONFIG[:root_url_text]}/datasets/#{dataset.key}"
      locNode.parent = urlNode

      priorityNode = doc.create_element('priority')
      priorityNode.content = "0.80"
      priorityNode.parent = urlNode

      updateNode = doc.create_element('lastmod')
      updateNode.content = dataset.updated_at.iso8601
      updateNode.parent = urlNode


      urlNode.parent = resourceNode
    end

    puts doc.to_xml(:save_with => Nokogiri::XML::Node::SaveOptions::AS_XML)

    sitemap_path = Rails.root.join('public', 'sitemaps', 'sitemap.xml')


    File.open(sitemap_path,'w') {|f| doc.write_xml_to f}



  end

  desc 'check_metadata_links'
  task :verify_metadata_links => :environment do

    notification = DatabankMailer.link_report()
    notification.deliver_now

  end

  desc 'delete all datasets'
  task :delete_all => :environment do

    if IDB_CONFIG[:local_mode] == true
      Dataset.all.each do |dataset|
        puts dataset.title
        dataset.destroy
      end
    else
      puts "Not local!"
    end

  end

  desc 'delete all datafiles'
  task :delete_files => :environment do

    if IDB_CONFIG[:local_mode] == true
      Datafile.all.each do |datafile|
        datafile.destroy
      end
    else
      puts "Not local!"
    end

  end

  desc 'delete all creators'
  task :delete_creators => :environment do
    Creator.all.each do |creator|
      creator.destroy
    end
  end

  desc "Clear users"
  task clear_users: :environment do
    User.all.each do |user|
      user.destroy
    end
    Identity.all.each do |identity|
      identity.destroy
    end
  end

  desc "Clear Rails cache (sessions, views, etc.)"
  task clear: :environment do
    Rails.cache.clear
  end

  desc 'Retroactively set publication_state'
  task :update_state => :environment do
    Dataset.where.not(identifier: "").each do |dataset|
      dataset.publication_state = Databank::PublicationState::RELEASED
      dataset.save!
    end
  end

  desc 'fix name and size display for files ingested into Medusa'
  task :update_filename => :environment do
    MedusaIngest.all.each do |ingest|
      if ingest.medusa_path && ingest.medusa_path != ""
        datafile = Datafile.where(web_id: ingest.idb_identifier).first
        if datafile && File.exist?("#{IDB_CONFIG['medusa']['medusa_path_root']}/#{ingest.medusa_path}")
          datafile.binary_size = File.size("#{IDB_CONFIG['medusa']['medusa_path_root']}/#{ingest.medusa_path}")
          datafile.binary_name = File.basename("#{IDB_CONFIG['medusa']['medusa_path_root']}/#{ingest.medusa_path}")
          datafile.save!
        else
          puts "could not find datafile: #{ingest.idb_identifier} for ingest #{ingest.id}"
        end
      end
    end
  end

  desc 'remove empty datasets more than 12 hours old'
  task :remove_datasets_empty_12h => :environment do
    drafts = Dataset.where(publication_state: Databank::PublicationState::DRAFT)
    drafts.each do |draft|
      unless ((draft.title && draft.title != '')||(draft.creators.count > 0)||(draft.datafiles.count > 0)||(draft.funders.count > 0) || (draft.related_materials.count > 0) || (draft.description && draft.description != '') || (draft.keywords && draft.keywords != '') )
        if draft.created_at < (12.hours.ago)
          draft.destroy
        end
      end
    end
  end

  desc 'get latest list of robot ip addresses'
  task :get_robot_addresses => :environment do

    Robot.destroy_all

    source_base = "http://www.iplists.com/"
    sources = Array.new
    sources.push("google")
    sources.push("inktomi")
    sources.push("lycos")
    sources.push("infoseek")
    sources.push("altavista")
    sources.push("excite")
    sources.push("northernlight")
    sources.push("misc")
    sources.push("non_engines")

    sources.each do |source|
      robot_list_url = "#{source_base}#{source}.txt"
      # puts robot_list_url
      open(robot_list_url){|io|
        io.each_line {|line|
          if line[0] != "#" && line != "\n"
            Robot.create(source: source, address: line)
          end
        }
      }
    end

  end

  desc 'remove download records with ip addresses, if they are more than 3 days old'
  task :scrub_download_records => :environment do
    DayFileDownload.where("download_date < ?", 3.days.ago ).destroy_all
  end

end
