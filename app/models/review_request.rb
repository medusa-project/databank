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

  # get the review request for this dataset requested after this review request, if any
  def next_review_request
    ReviewRequest.where('dataset_key = ? AND requested_at > ?', dataset_key, requested_at).order(:requested_at).first
  end

  def audits_since(time)
    dataset.audits.where('created_at >= ?', time)
  end

  def change_log
    # if there is a next review request, we want to get the audits between the current review request and the next one
    # sorted by created_at most recent first
    audits = if next_review_request
      audits_since(requested_at).where('created_at < ?', next_review_request.requested_at)
    else
      audits_since(requested_at)
    end
    audits.order(created_at: :desc).map do |audit|
      {action: audit.action,
      audited_changes: audit.audited_changes,
      created_at: audit.created_at}
    end
  end
end
