# frozen_string_literal: true

require "open-uri"

##
# Represents a creator as defined in DataCite metadata schema.
# A creator is a person or organization responsible for creating the resource.
#
# == Attributes
#
# * +dataset_id+ - foreign key for the dataset the creator belongs to
# * +type_of+ - type of creator, either "person" or "institution"
# * +email+ - email address of the creator, for a person or institution
# * +family_name+ - family name of the creator, for a person
# * +given_name+ - given name of the creator, for a person
# * +institution_name+ - name of the institution, for an institution
# * +identifier+ - ORCID identifier of the creator
# * +identifier_scheme+ - scheme of the identifier, always "ORCID"
# * +is_contact+ - true if the creator is the contact person for the dataset
# * +row_position+ - position of the creator in the list of creators, used in interface and citation
# * +row_order+ - order of the creator in the list of creators, not used

class Creator < ApplicationRecord
  include ActiveModel::Serialization
  belongs_to :dataset
  validate :name?
  after_create :add_editor
  after_update :add_editor
  after_create :set_dataset_nested_updated_at
  after_update :set_dataset_nested_updated_at
  before_destroy :set_dataset_nested_updated_at
  before_destroy :remove_editor

  audited except: [:row_order, :type_of, :identifier_scheme, :dataset_id, :institution_name], associated_with: :dataset

  default_scope { order(:row_position) }

  ##
  # Set the nested_updated_at attribute of the dataset to the current time
  def set_dataset_nested_updated_at
    dataset.update_attribute(:nested_updated_at, Time.now.utc)
  end

  ##
  # Find an ORCID identifier for a creator
  # @param [String] family_name
  # @param [String] given_names
  # @return [Hash] with keys "num-found" and "result"
  # "num-found" is the number of ORCID identifiers found
  # "result" is an array of hashes with key "orcid-identifier"
  # @example
  #  Creator.orcid_identifier(family_name: "Smith", given_names: "John")
  # => {"num-found"=>1, "result"=>[{"orcid-identifier"=>"0000-0002-1825-0097"}]}
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

  ##
  # Display information about a creator
  # @return [String] with family_name, given_name, and identifier
  # @example
  # creator.display_info
  # => "Smith, John, 0000-0002-1825-0097"
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

  ##
  # Query string for ORCID search
  # @param [String] family_name
  # @param [String] given_names
  # @return [String] query string
  def self.orcid_query_string(family_name: nil, given_names: nil)
    raise ArgumentError.new("requires at least one of family_name, given_names") if family_name.nil? && given_names.nil?

    return "search?q=given-names:#{given_names}*" if family_name.nil?

    return "search?q=family-name:#{family_name}*" if given_names.nil?

    "search?q=family-name:#{family_name}+AND+given-names:#{given_names}*"
  end

  ##
  # Add this creator as an editor to the dataset this creator belongs to
  def add_editor
    UserAbility.add_to_editors(dataset: dataset, email: email)
    Sunspot.index! [dataset]
  end

  ##
  # Remove this creator as an editor from the dataset this creator belongs to
  def remove_editor
    UserAbility.remove_from_editors(dataset: dataset, email: email)
    Sunspot.index! [dataset]
  end

  ##
  # JSON representation of a creator
  def as_json(*)
    if institution_name && institution_name != ""
      super(only: [:institution_name, :identifier, :is_contact, :row_position, :created_at, :updated_at])
    else
      super(only: [:family_name, :given_name, :identifier, :is_contact, :row_position, :created_at, :updated_at])
    end
  end

  ##
  # Display name for a creator
  # @return [String] with institution_name or family_name and given_name
  def display_name
    if type_of == Databank::CreatorType::INSTITUTION
      institution_name.to_s
    else
      "#{given_name || ''} #{family_name || ''}"
    end
  end

  ##
  # @return [String] with family_name, given_name, or institution_name
  def list_name
    if type_of == Databank::CreatorType::INSTITUTION
      institution_name.to_s
    else
      "#{family_name || ''}, #{given_name || ''}"
    end
  end

  ##
  # @return [Boolean] true if the creator is at the University of Illinois
  def at_illinois?
    return false unless type_of && type_of == Databank::CreatorType::PERSON && email && !email.empty?

    email[-12..] == "illinois.edu"
  end

  private

  ##
  # validation
  # @return [Boolean] true if the creator has a valid name, either as an institution or an individual
  def name?
    has_institution_name = institution_name && institution_name != ""
    has_individual_name = given_name && given_name != "" && family_name && family_name != ""
    has_institution_name || has_individual_name
  end
end
