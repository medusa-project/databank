# frozen_string_literal: true

# Represents the response that is returned by the extractor
# The Illinois Data Bank Archive Extractor is a microservice that extracts metadata
# from archive-type files such as zip, tar, and tar.gz
# https://wiki.library.illinois.edu/scars/Production_Services/Illinois_Data_Bank_Archive_Extractor
#
# == Attributes
#
# * +extractor_task_id+ - the id of the extractor task that this response is associated with
# * +status+ - the status of the extraction process
# * +response+ - the response from the extractor
# * +extractor_errors+ - the errors that occurred during the extraction process
# * +extractor_task+ - the extractor task that this response is associated with
class ExtractorResponse < ApplicationRecord
  belongs_to :extractor_task
  has_many :extractor_errors, dependent: :destroy
end
