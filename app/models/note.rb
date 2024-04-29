# frozen_string_literal: true

##
# Represents a note about a dataset for use by curators.
#
# == Attributes
#
# * +dataset_id+ - the dataset to which this note belongs
# * +body+ - the text of the note itself
# * +author+ - the author of the note

class Note < ApplicationRecord
  belongs_to :dataset
end
