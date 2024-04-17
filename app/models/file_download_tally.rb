# frozen_string_literal: true

##
# FileDownloadTally model
# This model is used to store the file download tallies

class FileDownloadTally < ApplicationRecord
  ##
  # should_be_public?
  # This instance method is used to check if the file download tally should be public
  # @return [Boolean] true if the file download tally should be public, false otherwise
  def should_be_public?

    datafile = Datafile.find_by(web_id: file_web_id)
    return false unless datafile

    dataset = datafile.dataset
    return false unless dataset

    return false unless dataset.metadata_public?

    return false if dataset.is_test

    return false unless created_at > dataset.release_datetime

    true
  end

  ##
  # public_tallies
  # This class method is used to get all the public tallies
  def self.public_tallies
    FileDownloadTally.all.select(&:should_be_public?)
  end
end
