# frozen_string_literal: true

##
# RestorationEvent model
# ---------------
# Represents a restoration event for use in migration or disaster recovery.
# Restores a dataset from the Medusa Collection Registry system and dataset files.
# ---------------
# Attributes
# ---------------
# event_type: string, required
# event_date: date, required
# event_description: text, optional
# created_at: datetime, required
# updated_at: datetime, required
# ---------------
# Associations
# ---------------
# has_many :restoration_id_maps
# ---------------
# Validations
# ---------------
# validates :event_type, presence: true
# validates :event_date, presence: true
# ---------------
# Methods
# ---------------
# as_json: Overrides the default as_json method to return only the necessary attributes
# ---------------

class RestorationEvent < ApplicationRecord
  has_many :restoration_id_maps, dependent: :destroy
end
