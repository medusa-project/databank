# frozen_string_literal: true

class RestorationEvent < ApplicationRecord
  has_many :restoration_id_maps, dependent: :destroy
end
