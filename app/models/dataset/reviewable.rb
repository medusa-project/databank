# frozen_string_literal: true

## This module is responsible for the review process of datasets.
# It is included in the Dataset model.
module Dataset::Reviewable
  extend ActiveSupport::Concern

  ##
  # Checks if the dataset is currently in pre-publication review
  # @return [Boolean] true if the dataset is in pre-publication review, false otherwise
  def in_pre_publication_review?
    Databank::PublicationState::DRAFT_ARRAY.include?(publication_state) && has_review_request?
  end

  ##
  # Checks if there is any review request for the dataset
  # returns last review request if exists, nil otherwise
  def latest_review_request
    ReviewRequest.where(dataset_key: key).order(created_at: :desc).first
  end

  ##
  # Checks if there is an unmodified review for the dataset
  # @return [Boolean] true if there is an unmodified review, false otherwise
  def has_unmodified_review?
    # set current_request to the latest review request for this dataset, if any exist
    current_request = latest_review_request
    return false unless current_request
    return !current_request.modified
  end
end