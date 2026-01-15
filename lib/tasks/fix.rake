require "csv"

namespace :fix do

  desc "populate all_medusa field of datasets"
  task check_medusa: :environment do 
    datasets = Dataset.select(&:files_public?)
    datasets.each do |dataset|
      # if all datafiles in dataset have a root value of 'medusa', set dataset's all_medusa field to true
      if dataset.datafiles.all? { |df| df.storage_root == 'medusa' }
        dataset.update(all_medusa: true) if !dataset.all_medusa
      else
        dataset.update(all_medusa: false) if dataset.all_medusa
      end
    end
  end

  desc "normalize user ability user.uids"
  task normalize_user_ability_uids: :environment do
    UserAbility.all.each do |ability|
      ability.user_uid = ability.user_uid.strip.downcase
      ability.save
    end
  end

  desc "ensure creator editors"
  task ensure_creator_editors: :environment do
    Dataset.all.each(&:ensure_creator_editors)
  end

  desc "hide embargoed resources"
  task hide_embargoed: :environment do
    Dataset.where(publication_state: Databank::PublicationState::RELEASED,
                  embargo:           [Databank::PublicationState::Embargo::FILE,
                            Databank::PublicationState::Embargo::METADATA]).each do |dataset|
      dataset.publication_state = dataset.embargo if release_date > Date.today
      dataset.save
    end
  end

  # to be run BEFORE switching dev system config to test system
  desc "report on doi states"
  task doi_report: :environment do
    Dataset.all.each do |dataset|
      puts "#{dataset.key}, #{dataset.doi_state}, #{dataset.publication_state}"
    end
  end

  desc "retrofit markdown text"
  task retrofit_markdown: :environment do
    markdown_extensions = ["md", "MD", "mdown", "mkdn", "mkd", "markdown"]
    Dataset.all.each do |dataset|
      dataset.datafiles.each do |datafile|
        file_parts = datafile.binary_name.split(".")
        if file_parts && markdown_extensions.include?(file_parts.last)
          datafile.peek_type = Databank::PeekType::MARKDOWN
          datafile.peek_text = Application.markdown.render(datafile.all_text_peek)

          datafile.save
        end
      end
    end
  end

  desc "update datacite metadata store"
  task update_datacite: :environment do
    datasets = Dataset.select(&:metadata_public?)
    datasets.each(&:update_doi)
  end
  
  desc "remove draft files if medusa ingest successful"
  task remove_draft_if_in_medusa: :environment do
    MedusaIngest.remove_draft_if_in_medusa
  end

  desc "update embargo state for released datasets"
  task fix_embargo_for_released: :environment do
    Dataset.all.each do |dataset|
      if dataset.publication_state == Databank::PublicationState::RELEASED && dataset.embargo != Databank::PublicationState::Embargo::NONE
        dataset.embargo = Databank::PublicationState::Embargo::NONE
        dataset.save!
      end
    end
  end

  desc "create doi objects from dataset identifiers"
  task retrofit_dois: :environment do
    Dataset.all.each do |dataset|
      if dataset.identifier && !dataset.identifier.empty?
        Doi.create!(dataset_id: dataset.id, identifier: dataset.identifier)
      end
    end
  end

  desc "update reviewer roles to network_reviewer"
  task fix_reviewers: :environment do
    Invitee.where(role: "reviewer").each do |invitee|
      invitee.update_attribute("role", Databank::UserRole::NETWORK_REVIEWER)
    end

    User.where(role: "reviewer").each do |user|
      user.update_attribute("role", Databank::UserRole::NETWORK_REVIEWER)
    end
  end

  desc "fix storage root for preserved files"
  task fix_storage_root: :environment do
    Datafile.where(storage_root: "draft").each(&:in_medusa)
  end

  desc "fix missing version"
  task fix_missing_version: :environment do
    datasets_missing_version = Dataset.where(dataset_version: nil)

    if datasets_missing_version.count > 0
      datasets_missing_version.each do |dataset|
        puts("Fixing missing version for dataset #{dataset.key}")
        dataset.dataset_version = "1"
        dataset.save
      end
    else
      puts("No datasets found with missing version.")
    end

  end

  desc "fix missing mime type"
  task fix_missing_mime: :environment do
    datafiles_missing_mime = Datafile.where(mime_type: nil)

    if datafiles_missing_mime.count > 0
      datafiles_missing_mime.each do |datafile|
        mime_guesses_set = MIME::Types.type_for(datafile.binary_name.downcase)
        if mime_guesses_set && mime_guesses_set.length > 0
          datafile.mime_type = mime_guesses_set[0].content_type
        else
          datafile.mime_type = "application/octet-stream"
        end
        datafile.save
      end
    end
  end

  desc "remove invalid creators"
  task remove_invalid_creators: :environment do
    Creator.all do |creator|
      unless (creator.institution_name && creator.institution_name != "") || (creator.given_name && creator.given_name != "" && creator.family_name && creatorbun.family_name != "")
        creator.destroy
      end
    end
  end

  desc "pretend some dev datasets never happened"
  task fix_dev: :environment do

    datasets_to_destroy = Dataset.where(key: ["IDBDEV-1772206"])

    datasets_to_destroy.each(&:destroy!)

  end

  desc "report top level mime types for datafiles on filesystem"
  task datafile_mimes: :environment do
    Datafile.all.each do |datafile|
      begin
        file_info = `file --mime "#{datafile.filepath}"`
        puts file_info
      rescue StandardError => ex
        puts ex.message
      end
    end
  end

  desc "remove orphan datafiles"
  task remove_orphan_datafiles: :environment do

    Datafile.all.each do |datafile|
      datasets = Dataset.where(id: datafile.dataset_id)
      datafile.destroy if datasets.count == 0
    end
  end

  desc "correct peek type for unsupported image mime types"
  task correct_image_peek: :environment do

    supported_image_subtypes = ["jp2", "jpeg", "dicom", "gif", "png", "bmp"]

    image_datafiles = Datafile.where(peek_type: Databank::PeekType::IMAGE)

    image_datafiles.each do |datafile|
      if datafile.mime_type && datafile.mime_type.length > 0 && datafile.mime_type.include?("/")
        mime_parts = datafile.mime_type.split("/")
        subtype = mime_parts[1].downcase

        unless supported_image_subtypes.include? (subtype)
          datafile.peek_type = Databank::PeekType::NONE
          datafile.save
        end
      else
        peek_type = Databank::PeekType::NONE
        datafile.save
      end
    end

  end

  desc "reset peek_type of none to nil for re-evaluation"
  task reset_none_peek: :environment do

    datafiles = Datafile.where(peek_type: Databank::PeekType::NONE)

    datafiles.each do |datafile|
      datafile.peek_type = nil
      datafile.save
    end

  end

  desc "reset peek_type of all text to nil for re-evaluation"
  task reset_text_peek: :environment do

    datafiles = Datafile.where(peek_type: Databank::PeekType::ALL_TEXT)

    datafiles.each do |datafile|
      datafile.peek_type = nil
      datafile.save
    end

  end

  desc "find invalid datafiles"
  task find_invalid_datafiles: :environment do
    Datafile.all.each do |datafile|
      if !datafile.storage_root
        puts "missing storage_root for datafile #{datafile.web_id}"
      elsif !datafile.storage_key
        puts "missing storage_key for datafile #{datafile.web_id}"
      elsif !datafile.current_root.exist?(datafile.storage_key)
        puts "missing binary for datafile #{datafile.web_id}, root: #{datafile.storage_root}, key: #{datafile.storage_key}"
      end
    end
  end


  desc "fix dev medusa dataset directory values"
  task fix_dev_medusa_dir: :environment do

    cfs_hash = Hash.new

    CSV.foreach(Rails.root.join("public", "dev_doi_cfs.csv")) do |row|
      cfs_hash[row[1]] = row[0]
    end

    Dataset.all.each do |dataset|
      if dataset.publication_state != Databank::PublicationState::DRAFT
        dataset.medusa_dataset_dir = "/cfs_directories/#{cfs_hash[dataset.dirname]}"
        dataset.save
      end
    end

  end

  desc "fix aws medusa dataset directory values"
  task fix_aws_medusa_dir: :environment do

    cfs_hash = Hash.new

    CSV.foreach(Rails.root.join("public", "aws_doi_cfs.csv")) do |row|
      cfs_hash[row[1]] = row[0]
    end

    Dataset.all.each do |dataset|
      if dataset.publication_state != Databank::PublicationState::DRAFT
        dataset.medusa_dataset_dir = "/cfs_directories/#{cfs_hash[dataset.dirname]}"
        dataset.save
      end
    end

  end

  desc "fix prod medusa dataset directory values"
  task fix_prod_medusa_dir: :environment do

    cfs_hash = Hash.new

    CSV.foreach(Rails.root.join("public", "prod_doi_cfs.csv")) do |row|
      cfs_hash[row[1]] = row[0]
    end

    Dataset.all.each do |dataset|
      if dataset.publication_state != Databank::PublicationState::DRAFT
        dataset.medusa_dataset_dir = "/cfs_directories/#{cfs_hash[dataset.dirname]}"
        dataset.save
      end
    end

  end

  desc "make datacite record not findable as appropriate for datasets"
  task redact_from_datacite: :environment do

    test = Dataset.where(is_test: true)

    held = Dataset.where(hold_state: Databank::PublicationState::TempSuppress::METADATA)

    suppressed = Dataset.where(publication_state: [Databank::PublicationState::TempSuppress::METADATA, Databank::PublicationState::PermSuppress::METADATA])

    embargoed = Dataset.where(publication_state: Databank::PublicationState::Embargo::METADATA)

    [test, held, suppressed, embargoed].each do |recordset|
      recordset.each(&:hide_doi)
    end

  end

  desc "make dev datasets not findable in datacite"
  task redact_dev: :environment do

    Dataset.where.not(publication_state: Databank::PublicationState::DRAFT).each(&:hide_doi) if Rails.env.development?

  end

  desc "fix specific test records in datacite"
  task fix_datacite_custom: :environment do

    host = IDB_CONFIG[:datacite][:endpoint]
    user = IDB_CONFIG[:datacite][:username]
    password = IDB_CONFIG[:datacite][:password]

    bad_records = ["10.26123/idbdev-1772206_v1",
     "10.26123/idbdev-2774199_v1",
     "10.26123/idblocal-5622337_v1",
     "10.26123/testidb-6183513"]

    bad_records.each do |identifier|
      uri = URI.parse("https://#{host}/metadata/#{identifier}" )

      request = Net::HTTP::Delete.new(uri.request_uri)
      request.basic_auth(user, password)
      request.content_type = "text/plain"

      sock = Net::HTTP.new(uri.host, uri.port)
      sock.use_ssl = true

      sock.start { |http| http.request(request) }
    end


  end

  desc "migrate demo datasets"
  task migrate_demo_datasets: :environment do

    host = IDB_CONFIG[:datacite_test_endpoint]
    user = IDB_CONFIG[:datacite_test_username]
    password = IDB_CONFIG[:datacite_test_password]
    shoulder = IDB_CONFIG[:datacite_test_shoulder]

    Dataset.all.each do |dataset|
      if dataset.identifier && dataset.identifier.include?("10.5072/FK2")
        dataset.identifier = "#{shoulder}#{dataset.key}_V1"


        target = "#{IDB_CONFIG[:root_url_text]}/datasets/#{dataset.key}"

        uri = URI.parse("https://#{host}/doi")

        request = Net::HTTP::Post.new(uri.request_uri)
        request.basic_auth(user, password)
        request.content_type = "text/plain;charset=UTF-8"
        request.body = "doi=#{dataset.identifier}\nurl=#{target}"

        sock = Net::HTTP.new(uri.host, uri.port)
        # sock.set_debug_output $stderr
        sock.use_ssl = true

        begin

          response = sock.start { |http| http.request(request) }

        rescue Net::HTTPBadResponse, Net::HTTPServerError => error
          puts "\nerror:" + error.message
          puts "\nresponse body: " + response.body

        end

        case response
        when Net::HTTPSuccess, Net::HTTPCreated, Net::HTTPRedirection
          dataset.save
        else
          puts "\nnot successful:"
          puts "\nrequest: " + request.to_yaml
          puts "\nresponse: " + response.to_yaml
        end

      end
    end
  end

  desc "charstuff"
  task charstuff: :environment do
    test_path = "/Users/mfall3/Downloads/Bobcat data description.txt"
    if File.file?(test_path)
      content = File.read(test_path)
      content.gsub!(/[”“]/, '"')
      content.gsub!(/[‘’]/, "'")
      puts content
    else
      puts "file not found"
    end
  end

  desc "remove orphan Review Request records"
  task remove_orphan_review_requests: :environment do
    ReviewRequest.all.each do |review_request|
      review_request.destroy if review_request.dataset.nil?
    end
  end

end
