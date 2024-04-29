# frozen_string_literal: true

##
# Represents the file download tallies
#
# == Attributes
#
# * +file_web_id+ - the web id of the downloaded file
# * +filename+ - the name of the downloaded file
# * +tally+ - the number of downloads
# * +download_date+ - the date of the download
# * +dataset_key+ - the key of the associated dataset
# * +doi+ - the doi of the associated dataset

class FileDownloadTally < ApplicationRecord
  ##
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
  # @return [Array<FileDownloadTally>] the public file download tallies
  def self.public_tallies
    FileDownloadTally.all.select(&:should_be_public?)
  end
end
