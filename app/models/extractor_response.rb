# frozen_string_literal: true

# ExtractorResponse model
# This model is used to hold the response that is returned by the extractor
class ExtractorResponse < ApplicationRecord
  belongs_to :extractor_task
  has_many :extractor_errors, dependent: :destroy
end
