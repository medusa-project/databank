# frozen_string_literal: true

##
# Funder model
# This model is used to store the funders
# Every funder belongs to a dataset
# Every funder has a name, identifier, identifier_scheme, and grant
# The list of funders is displayed in the dataset show page
# The most common funders can be selected from a dropdown list
# The dropdown list is populated from the FUNDER_INFO_ARR array in the aa_first.rb initializer
# The identifier and identifier_scheme for all the listed funders are DOI-based
# The grant identifier is optional, but when it is provided, it is displayed in the dataset show page
# Attributes:
# - name: string, the name of the funder
# - identifier: string, the identifier of the funder, usually from CrossRef Funder Registry
# - identifier_scheme: string, the scheme for the identifier, usually DOI
# - grant: string, the grant identifier

class Funder < ApplicationRecord
  include ActiveModel::Serialization
  belongs_to :dataset
  audited associated_with: :dataset
  validates :dataset_id, presence: true
  after_create :set_dataset_nested_updated_at
  after_update :set_dataset_nested_updated_at
  before_destroy :set_dataset_nested_updated_at

  ##
  # as_json
  # This method is used to return a hash of the funder object
  def as_json(_options={})
    super(only: %i[name identifier identifier_scheme grant created_at updated_at])
  end

  ##
  # set_dataset_nested_updated_at
  # This method is used to update the nested_updated_at attribute of the dataset
  def set_dataset_nested_updated_at
    dataset.update_attribute(:nested_updated_at, Time.now.utc)
  end

  ##
  # display_info
  # This instance method is used to return the display information for the funder for the dataset show page
  # @return [String] the display information for the funder
  # If the grant is present, the display information is the name of the funder followed by the grant
  def display_info
    return "#{name}-Grant:#{grant}" if grant.present?

    name
  end
end
