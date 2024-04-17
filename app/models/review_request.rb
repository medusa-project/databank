# frozen_string_literal: true

##
# ReviewRequest model
# ---------------
# Represents a request for a dataset review.
# ---------------
# Attributes
# ---------------
# dataset_key: string, required
# requestor_email: string, required
# requestor_name: string, required
# requestor_institution: string, required
# requestor_position: string, required
# requestor_phone: string, required
# requestor_reason: text, required
# requestor_comments: text, optional
# ---------------
# Associations
# ---------------
# None
# ---------------
# Validations
# ---------------
# validates :dataset_key, presence: true
# validates :requestor_email, presence: true
# validates :requestor_name, presence: true
# validates :requestor_institution, presence: true
# validates :requestor_position, presence: true
# validates :requestor_phone, presence: true
# validates :requestor_reason, presence: true
# ---------------
# Methods
# ---------------
# dataset: Returns the dataset associated with the review request
# ---------------

class ReviewRequest < ApplicationRecord
  ##
  # dataset
  # Returns the dataset associated with the review request
  # @return [Dataset]
  def dataset
    Dataset.find_by(key: dataset_key)
  end
end
