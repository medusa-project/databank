# frozen_string_literal: true

##
# ReviewRequest model
# ---------------
# Represents a request for a dataset review.
#
# == Attributes
#
# * +dataset_key+ - the key of the dataset the review request is for
# * +requested_at+ - the time the review request was made

class ReviewRequest < ApplicationRecord
  ##
  # dataset
  # Returns the dataset associated with the review request
  # @return [Dataset]
  def dataset
    Dataset.find_by(key: dataset_key)
  end

end
