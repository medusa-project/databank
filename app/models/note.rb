# frozen_string_literal: true

##
# Note model
# @note: This model is used to store the notes of the dataset for use by curators
# @note: This model is associated with the Dataset model

class Note < ApplicationRecord
  belongs_to :dataset
end
