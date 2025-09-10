require 'json'

namespace :bulk do
  desc 'ingest records from cabbi'
  task :cabbi => :environment do
    raise("already done, do not run again")
    # file_path = Rails.root.join('public', 'cabbi_metadata_2025-08-28.json')
    # json_data = JSON.parse(File.read(file_path))
    # count = 0
    # report_array = []
    # json_data.each do |record|
    #   count = count + 1
    #   puts "Processing record #{count}: #{record['DatasetTitle']}"
    #   primary_contact = nil
    #   record["Authors"].each do |author|
    #     if author["PrimaryContact"]
    #       primary_contact = author
    #       break
    #     end
    #   end
    #   dataset = create_dataset_from_cabbi(record: record, primary_contact: primary_contact)
    #   dataset_url = "#{IDB_CONFIG[:root_url_text]}/datasets/#{dataset.key}"
    #   report_array << {cabbi_record: count, dataset_id: dataset.id, databank_url: dataset_url, doi: dataset.identifier, title: dataset.title}
    # end
 
    # puts "Total records: #{count}"
    # puts "Report:"
    # puts report_array.to_json

  end
  
  desc 'create tsv files from cabbi report'
  task :cabbi_tsv => :environment do
    raise("already done, do not run again")
    # require 'csv'
    # file_path = Rails.root.join('public', 'cabbi_report_2025-09-05.json')
    # json_data = JSON.parse(File.read(file_path))
    # tsv_file_path = Rails.root.join('public', 'cabbi_report_2025-09-05.tsv')

    # CSV.open(tsv_file_path, 'w', col_sep: "\t") do |tsv|
    #   tsv << ["cabbi_record", "dataset_id", "databank_url", "doi", "title"]
    #   json_data.each do |record|
    #     tsv << [record["cabbi_record"], record["dataset_id"], record["databank_url"], record["doi"], record["title"]]
    #   end
    # end

    # puts "TSV file created at #{tsv_file_path}"
  end

  desc 'add cabbi editor role to datasets'
  task :cabbi_editor => :environment do
    raise("already done, do not run again")
    # case Rails.env
    # when "prod-rocky"
    #   cabbi_editor = User.find_by(email: "krhodges@illinois.edu")
    # when "demo-rocky"
    #   cabbi_editor = User.find_by(email: "srobbins@illinois.edu")
    # else
    #   cabbi_editor = User.find_by(email: "researcher2@mailinator.com")
    # end
    # raise "CABBI editor user not found" if cabbi_editor.nil?

    # file_path = Rails.root.join('public', 'cabbi_metadata_2025-08-28.json')
    # json_data = JSON.parse(File.read(file_path))
    # count = 0
    # json_data.each do |record|
    #   count = count + 1
    #   puts "Processing record #{count}: #{record['dataset_id']}"
    #   dataset = Dataset.find_by(title: record["DatasetTitle"])
    #   if dataset.present?
    #     if [ "prod-rocky", "demo-rocky"].include?(Rails.env)
    #       UserAbility.add_to_editors(dataset: dataset, email: cabbi_editor.email)
    #     else
    #       puts "not valid, must be tested on demo"
    #     end
    #     puts "Added CABBI editor to dataset #{dataset.id}"
    #   else
    #     puts "Dataset not found for title: #{record['DatasetTitle']}"
    #   end
    # end
  end
end

# assumes all are CCBY4, check for any new batch 
def create_dataset_from_cabbi(record:, primary_contact:)
  case Rails.env
  when "prod-rocky"
    depositor = {name: "Leslie A. Stoecker", email: "lensor@illinois.edu"}
  when "demo-rocky"
    depositor = {name: "Colleen Fallaw", email: "mfall3@illinois.edu"}
  else
    depositor = {name: "Researcher 1", email: "researcher1@mailinator.com"}
  end

  dataset = Dataset.new(
    title: record["DatasetTitle"],
    publisher: "University of Illinois Urbana-Champaign",
    description: record["DatasetDescription"],
    license: "CCBY4",
    depositor_name: depositor[:name],
    depositor_email: depositor[:email],
    complete: nil,
    corresponding_creator_name:"#{primary_contact['FamilyName']}, #{primary_contact['GivenName']}",
    corresponding_creator_email: primary_contact["Email"],
    keywords: record["Keywords"]&.join(";"),
    subject: "Life Sciences",
    publication_state: "draft",
    curator_hold: false,
    release_date: record["PublicationDate"],
    embargo: "none",
    is_test: false,
    is_import: false,
    have_permission: "yes",
    removed_private: "yes",
    agree: "yes",
    hold_state: "none",
    dataset_version: "1",
    suppress_changelog: false,
    org_creators: false
  )
  dataset.save!
  dataset.identifier = dataset.default_identifier
  dataset.save!

  add_authors(dataset: dataset, record: record, depositor: depositor) # authors required and always present
  add_funder(dataset: dataset, record: record) if record["FunderName"].present?
  add_related_materials(dataset: dataset, record: record) if record["OtherResources"].present?
  dataset
end

def add_authors(dataset:, record:, depositor:)
  record["Authors"].each_with_index do |author, index|
    author_orcid = author["ORCiD"].present? ? author["ORCiD"] : ""
    author_email = author["Email"].present? ? author["Email"] : depositor[:email]
    author_orcid = author["ORCID"]
    dataset_author = Creator.new(
      dataset_id: dataset.id,
      family_name: author["FamilyName"],
      given_name: author["GivenName"],
      identifier: author_orcid,
      type_of: 0,
      row_order: nil,
      email: author_email,
      is_contact: author["PrimaryContact"] ? true : false,
      row_position: index + 1,
      identifier_scheme: "ORCID"
    )
    dataset_author.save
  end
end

def add_funder(dataset:, record:)
  cabbi_funder_name = record["FunderName"]
  cabbi_grant_identifier = record["FunderGrantNumber"]
  funder_info = funder_info_from_name(funder_name: cabbi_funder_name)
  funder = Funder.new(
    dataset_id: dataset.id,
    name: funder_info[:name],
    identifier: funder_info[:identifier],
    identifier_scheme: funder_info[:identifier_scheme],
    grant: cabbi_grant_identifier,
    code: funder_info[:code])
  funder.save
end

def funder_info_from_name(funder_name:)
  dataset_funder = FUNDER_INFO_ARR.find { |f| f.name.downcase.include?(funder_name.downcase) }
  dataset_funder || {name: funder_name, identifier: nil, identifier_scheme: nil, code: nil}
end

def add_related_materials(dataset:, record:)
  record["OtherResources"].each do |resource|
    uri_info = uri_info_from_url(url: resource["URLtoResource"])
    related_material = RelatedMaterial.new(
      dataset_id: dataset.id,
      datacite_list: "IsSupplementTo",
      material_type: resource["RelatedResourceType"],
      selected_type: resource["RelatedResourceType"],
      link: resource["URLtoResource"],
      uri: uri_info[:uri],
      uri_type: uri_info[:uri_type],
      citation: resource["Citation"]
    )
    related_material.save
  end
end

def uri_info_from_url(url:)
  if url.start_with?("https://doi.org/") 
    {uri: url.delete_prefix("https://doi.org/"), uri_type: "DOI"}
  else
    {uri: url, uri_type: "Other"}
  end
end