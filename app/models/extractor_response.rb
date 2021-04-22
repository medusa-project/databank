class ExtractorResponse < ApplicationRecord
  belongs_to :extractor_task
  has_many :extractor_errors, dependent: :destroy
end
