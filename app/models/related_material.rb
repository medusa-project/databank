# frozen_string_literal: true

##
# RelatedMaterial model
# ---------------
# Represents a related material as defined in DataCite metadata schema
# As originally designed, a material can have multiple relationships to the dataset, which are stored in a single string
# Q1 2024 Curators determined that the relationships should be cited or supported, not both, which is a change
# The curators actualized this change of policy by changing the values in the interface
# Future development possibility: if each related material has exactly one relationship,
# the list/hash could be eliminated for streamlined processing.
# ---------------
# Attributes
# ---------------
# material_type: string, required
# availability: string, optional
# link: string, optional
# uri: string, optional
# uri_type: string, optional
# citation: string, optional
# dataset_id: integer, required
# created_at: datetime, required
# updated_at: datetime, required
# ---------------
# Associations
# ---------------
# belongs_to :dataset
# audited associated_with: :dataset
# ---------------
# Validations
# ---------------
# validates :material_type, presence: true
# validates :dataset_id, presence: true
# ---------------
# Methods
# ---------------
# as_json: Overrides the default as_json method to return only the necessary attributes
# relationship_arr: Returns an array of relationships for this material
# display_info: Returns a string of the material's information
# nonversion_relationships: Returns an array of relationships that are not version-related
# link_status: Returns the status of the link, if it exists
# report_row: Returns a string of the material's information for the link report
# set_dataset_nested_updated_at: Updates the dataset's nested_updated_at attribute
# link_report: Returns an html string of the link report table
# link_attempt_status: Returns the status of the link attempt
# ---------------

require "rest-client"
require "uri"

class RelatedMaterial < ApplicationRecord
  include ActiveModel::Serialization
  belongs_to :dataset
  audited associated_with: :dataset
  after_create :set_dataset_nested_updated_at
  after_update :set_dataset_nested_updated_at
  before_destroy :set_dataset_nested_updated_at

  ##
  # as_json
  # Overrides the default as_json method to return only the necessary attributes
  def as_json(*)
    super(only: %i[material_type
                   availability
                   link
                   uri
                   uri_type
                   citation
                   dataset_id
                   created_at
                   updated_at])
  end

  ##
  # relationship_arr
  # Returns an array of relationships for this material
  # If datacite_list is not empty, it splits the string by comma and returns the array
  # Otherwise, it returns an empty array
  # @return [Array] an array of relationships
  def relationship_arr
    if datacite_list && datacite_list != ""
      datacite_list.split(",")
    else
      []
    end
  end

  ##
  # display_info
  # Returns a string of the material's information for use in UI
  # @return [String] a string of the material's information, such as material_type, link, uri, or citation
  def display_info
    info_arr = []
    info_arr << material_type if material_type.present?
    info_arr << link if link.present?
    info_arr << uri if uri.present?
    info_arr << citation if citation.present?
    info_arr.join(", ")
  end

  ##
  # nonversion_relationships
  # Returns an array of relationships that are not version-related
  # @return [Array] an array of relationships that are not version-related
  def nonversion_relationships
    relationship_arr - %w[IsPreviousVersionOf IsNewVersionOf]
  end

  ##
  # link_status
  # Returns the status of the link, if it exists
  # If there are no non-version related materials, it returns "no non-version related materials"
  # If there is no link, it returns "no link"
  # If the link is not a valid URL, it returns "invalid url"
  # Otherwise, it returns the status of the link attempt
  # @return [String] the status of the link
  def link_status
    return "no non-version related materials" unless nonversion_relationships.count.positive?

    return "no link" unless link

    return "invalid url" unless link =~ /\A#{URI::DEFAULT_PARSER.make_regexp(%w[http https])}\z/

    link_attempt_status
  end

  ##
  # report_row
  # Returns a string of the material's information for the link report
  # If there are no non-version related materials, it returns an empty string
  # Otherwise, it returns a string of the material's information for the link report
  # @return [String] a string of the material's information for the link report
  def report_row
    return "" unless nonversion_relationships.count.positive?

    "<tr><td>#{dataset.identifier}</td>\
<td>#{IDB_CONFIG[:root_url_text]}/datasets/#{dataset.key}</td>\
<td>#{selected_type}</td><td>#{nonversion_relationships}</td>\
<td>#{link}</td><td>#{link_status}</td></tr>"
  end

  def set_dataset_nested_updated_at
    dataset.update_attribute(:nested_updated_at, Time.now.utc)
  end

  ##
  # link_report (class method
  # This method selects all datasets that are not test datasets and have public metadata
  # It then iterates through each dataset's related materials and returns
  # a string of the material's information for the link report
  # @return [String] an html string of the link report table
  def self.link_report
    datasets = Dataset.where(is_test: false).select(&:metadata_public?)
    report = "<table border='1'><tr>\
<th>DOI</th><th>Dataset_URL</th><th>Material_Type</th><th>Relationship</th>\
<th>Material_URL</th><th>Status_Code</th></tr>"
    datasets.each do |dataset|
      dataset.related_materials.each do |material|
        report += material.report_row
      end
    end
    report += "</table>"
  end

  private

  ##
  # link_attempt_status
  # Returns a link status given a validly formatted link.
  # If the link is not accessible, it returns the appropriate error message
  # @return [String] the status of the link
  def link_attempt_status
    RestClient.get link
  rescue RestClient::Unauthorized, RestClient::Forbidden => e
    "access denied"
  rescue RestClient::RequestTimeout
    "timeout"
  rescue RestClient::SSLCertificateNotVerified
    "SSL certificate not verified"
  rescue RestClient::Exception
    "invalid or unresponsive"
  else
    "ok"
  end
end
