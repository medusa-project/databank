# frozen_string_literal: true

##
# DatasetDownloadTally
# ---------------
# Model for dataset download tallies.
#
# A dataset download tally is a record of a download of a dataset.
# It includes the dataset key, the DOI of the dataset, and the time of the download.
# The dataset key is a unique identifier for the dataset within the Illinois Data Bank system.
# The DOI is a unique identifier for the dataset for registering with DataCite.
# The time of the download is a timestamp of when the download occurred.

class DatasetDownloadTally < ApplicationRecord

  ##
  # should_be_public?
  # ---------------
  # Determines if the dataset download tally should be public.
  # A dataset download tally should be public if the dataset is public, the dataset is not a test dataset,
  # and the download occurred after the dataset was released.
  # @return [Boolean] true if the dataset download tally should be public, false otherwise.
  def should_be_public?
    return false if doi.empty?

    dataset = Dataset.find_by(key: dataset_key)

    return false unless dataset

    return false unless dataset.metadata_public?

    return false if dataset.is_test

    return false unless created_at > dataset.release_datetime

    true
  end

  ##
  # public_tallies
  # ---------------
  # Gets all dataset download tallies that should be public.
  def self.public_tallies
    DatasetDownloadTally.all.select(&:should_be_public?)
  end
end
