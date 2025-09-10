# frozen_string_literal: true

##
# SystemFile
# ---------------
# Represents a file used by the system, such as a serialization file, in contrast to a datafile
# # == Attributes
# * +dataset_id+ - the id of the dataset the file is associated with
# * +storage_root+ - the root directory for the file
# * +storage_key+ - the key of the file within the root directory
# * +file_type+ - the type of the file, such as 'serialization'
class SystemFile < ApplicationRecord
  belongs_to :dataset
end
