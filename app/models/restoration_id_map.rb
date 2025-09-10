# frozen_string_literal: true

##
# RestorationIdMap model
# ---------------
# Represents a mapping of dataset ids from the Medusa Collection Registry system to the local system.
# ---------------
# Attributes
# ---------------
# medusa_id: integer, required
# local_id: integer, required
# ---------------
# Associations
# ---------------
# belongs_to :restoration_event
# audited associated_with: :restoration_event
# ---------------
# Validations
# ---------------
# validates :medusa_id, presence: true
# validates :local_id, presence: true
class RestorationIdMap < ApplicationRecord
end
