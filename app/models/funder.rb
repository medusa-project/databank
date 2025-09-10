# frozen_string_literal: true

##
# Represents a funder for a dataset
#
# == Attributes
#
# * +name+ - the name of the funder
# * +identifier+ - the identifier of the funder
# * +identifier_scheme+ - the identifier scheme of the funder
# * +grant+ - the grant number of the funder
# * +dataset_id+ - the id of the dataset the funder belongs to
# * +code+ - the code of the funder, for use in the dataset form

class Funder < ApplicationRecord
  include ActiveModel::Serialization
  belongs_to :dataset
  audited associated_with: :dataset
  validates :dataset_id, presence: true
  after_create :set_dataset_nested_updated_at
  after_update :set_dataset_nested_updated_at
  before_destroy :set_dataset_nested_updated_at

  ##
  # @return [Hash] the funder as a hash
  def as_json(_options={})
    super(only: %i[name identifier identifier_scheme grant created_at updated_at])
  end

  ##
  # updates the nested_updated_at attribute of the associated Dataset for use when this funder is updated
  def set_dataset_nested_updated_at
    dataset.update_attribute(:nested_updated_at, Time.now.utc)
  end

  ##
  # @return [String] the display information for the funder
  # If the grant is present, the display information is the name of the funder followed by the grant
  def display_info
    return "#{name}-Grant:#{grant}" if grant.present?

    name
  end
end
