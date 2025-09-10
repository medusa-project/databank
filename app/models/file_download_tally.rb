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

    return false unless dataset.release_datetime

    return false if dataset.is_test

    return false unless created_at > dataset.release_datetime

    true
  end

  ##
  # @return [Array<FileDownloadTally>] the public file download tallies
  def self.public_tallies
    FileDownloadTally.all.select(&:should_be_public?)
  end

  ##
  # Gets the dataset download tallies for the dataset.
  # @param [String] dataset_key the key of the dataset.
  # @return [Array<FileDownloadTally>] the dataset download tallies for the dataset.
  def self.datafile_download_tallies(web_id)
    FileDownloadTally.where(file_web_id: web_id)
  end

  ##
  # Gets the datafile download tallies for the dataset that should be public
  # @param [String] web_id the web_id of the datafile.
  # @return [Array<FileDownloadTally>] the datafile download tallies for the datafile that should be public.
  def self.public_datafile_download_tallies(web_id)
    datafile_download_tallies(web_id).select(&:should_be_public?)
  end

  ##
  # Gets the datafile download tallies that should be public, grouped by datafile web_id.
  def self.public_downloads_by_web_id
    tally_hash = {}
    grouped = public_tallies.group_by(&:file_web_id)
    grouped.each {|key, value| tally_hash[key] = value.sum(&:tally)}
    tally_hash
  end

  ##
  # Gets the total number of downloads for the dataset.
  # @param [String] dataset_key the key of the dataset.
  # @return [Integer] the total number of downloads for the dataset.
  def self.total_downloads(web_id)
    FileDownloadTally.where(file_web_id: web_id).sum :tally
  end
end
