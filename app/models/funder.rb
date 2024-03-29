# frozen_string_literal: true

class Funder < ApplicationRecord
  include ActiveModel::Serialization
  belongs_to :dataset
  audited associated_with: :dataset
  validates :dataset_id, presence: true
  after_create :set_dataset_nested_updated_at
  after_update :set_dataset_nested_updated_at
  before_destroy :set_dataset_nested_updated_at
  def as_json(_options={})
    super(only: %i[name identifier identifier_scheme grant created_at updated_at])
  end
  def set_dataset_nested_updated_at
    dataset.update_attribute(:nested_updated_at, Time.now.utc)
  end
  def display_info
    return "#{name}-Grant:#{grant}" if grant.present?

    name
  end
end
