# frozen_string_literal: true

class Funder < ApplicationRecord
  include ActiveModel::Serialization
  belongs_to :dataset
  audited associated_with: :dataset
  validates :dataset_id, presence: true

  def as_json(_options={})
    super(only: %i[name identifier identifier_scheme grant created_at updated_at])
  end
end
