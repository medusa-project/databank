# frozen_string_literal: true

require "open-uri"

# represents a creator as defined in DataCite metadata schema
class Creator < ApplicationRecord
  include ActiveModel::Serialization
  belongs_to :dataset
  validate :name?
  after_create :add_editor
  after_update :add_editor
  before_destroy :remove_editor

  audited except: [:row_order, :type_of, :identifier_scheme, :dataset_id, :institution_name], associated_with: :dataset

  default_scope { order(:row_position) }

  def self.orcid_identifier(family_name: nil, given_names: nil)
    query_string = Creator.orcid_query_string(family_name: family_name, given_names: given_names)
    url = URI("#{IDB_CONFIG[:orcid][:endpoint_base]}#{query_string}")
    response = url.read
    compact_response = response.gsub(/\\n/, "").gsub(/>\s*/, ">").gsub(/\s*</, "<")
    response_doc = Nokogiri::XML(compact_response)
    num_found_nodeset = response_doc.xpath("/*/@num-found")
    identifier_nodeset = response_doc.xpath("//common:path")
    result = []
    identifier_nodeset.each do |identifier_node|
      result << {"orcid-identifier" => identifier_node.text}
    end
    {"num-found" => num_found_nodeset[0].value.to_i, "result" => result}
  end

  def display_info
    "#{display_name}, #{email}, #{identifier}"
  end

  def self.orcid_person(orcid:)
    url = URI("#{IDB_CONFIG[:orcid][:endpoint_base]}#{orcid}/record")
    response = url.read
    compact_response = response.gsub(/\\n/, "").gsub(/>\s*/, ">").gsub(/\s*</, "<")
    response_doc = Nokogiri::XML(compact_response)
    family_name = response_doc.xpath("//personal-details:family-name")[0].text
    given_names = response_doc.xpath("//personal-details:given-names")[0].text
    affiliation_nodeset = response_doc.xpath("//common:organization/common:name")
    affiliation = if affiliation_nodeset.length.zero?
                    "not provided"
                  else
                    affiliation_nodeset[0].text
                  end
    {family_name: family_name, given_names: given_names, affiliation: affiliation}
  end

  def self.orcid_query_string(family_name: nil, given_names: nil)
    raise ArgumentError.new("requires at least one of family_name, given_names") if family_name.nil? && given_names.nil?

    return "search?q=given-names:#{given_names}*" if family_name.nil?

    return "search?q=family-name:#{family_name}*" if given_names.nil?

    "search?q=family-name:#{family_name}+AND+given-names:#{given_names}*"
  end

  def add_editor
    UserAbility.add_to_editors(dataset: dataset, email: email)
    Sunspot.index! [dataset]
  end

  def remove_editor
    UserAbility.remove_from_editors(dataset: dataset, email: email)
    Sunspot.index! [dataset]
  end

  def as_json(*)
    if institution_name && institution_name != ""
      super(only: [:institution_name, :identifier, :is_contact, :row_position, :created_at, :updated_at])
    else
      super(only: [:family_name, :given_name, :identifier, :is_contact, :row_position, :created_at, :updated_at])
    end
  end

  def display_name
    if type_of == Databank::CreatorType::INSTITUTION
      institution_name.to_s
    else
      "#{given_name || ''} #{family_name || ''}"
    end
  end

  # text for the name when used in a list
  def list_name
    if type_of == Databank::CreatorType::INSTITUTION
      institution_name.to_s
    else
      "#{family_name || ''}, #{given_name || ''}"
    end
  end

  def at_illinois?
    return false unless type_of && type_of == Databank::CreatorType::PERSON && email && !email.empty?

    email[-12..] == "illinois.edu"
  end

  private

  # validation
  def name?
    has_institution_name = institution_name && institution_name != ""
    has_individual_name = given_name && given_name != "" && family_name && family_name != ""
    has_institution_name || has_individual_name
  end
end
