# frozen_string_literal: true

##
# Robot model
# ---------------
# Represents a robot that can be excluded from download counts.
# ---------------
# Attributes
# ---------------
# name: string, required
# description: text, optional
# ---------------
# Associations
# ---------------
# None
# ---------------
# Validations
# ---------------
# validates :name, presence: true
# ---------------
# Methods
# ---------------
# None

class Robot < ApplicationRecord
end
