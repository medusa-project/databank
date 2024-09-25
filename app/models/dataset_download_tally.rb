# frozen_string_literal: true

##
# Represents dataset download tallies.
#
# A dataset download tally is a record of a download of a dataset.
# It includes the dataset key, the DOI of the dataset, and the time of the download.
# The dataset key is a unique identifier for the dataset within the Illinois Data Bank system.
# The DOI is a unique identifier for the dataset for registering with DataCite.
# The time of the download is a timestamp of when the download occurred.
#
# == Attributes
#
# * +dataset_key+ - the key of the dataset that was downloaded.
# * +doi+ - the DOI of the dataset that was downloaded.
# * +download_date+ - the date and time of the download.
# * +tally+ - the number of times the dataset has been downloaded on this date

class DatasetDownloadTally < ApplicationRecord

  ##
  # Determines if the dataset download tally should be public.
  # A dataset download tally should be public if the dataset is public, the dataset is not a test dataset,
  # and the download occurred after the dataset was released.
  # @return [Boolean] true if the dataset download tally should be public, false otherwise.
  def should_be_public?
    return false if doi.empty?

    dataset = Dataset.find_by(key: dataset_key)

    return false unless dataset

    return false if dataset.is_test

    return false unless dataset.release_datetime

    return false unless created_at > dataset.release_datetime

    true
  end

  ##
  # Gets all dataset download tallies that should be public.
  def self.public_tallies
    DatasetDownloadTally.all.select(&:should_be_public?)
  end

  ##
  # Gets all dataset download tallies that should be public, grouped by dataset key.
  def self.public_tallies_by_dataset_key
    public_tallies.group_by(&:dataset_key)
  end

  def self.public_tally_count_by_dataset_key
    tally_hash = {}
    public_tallies_by_dataset_key.each {|key, value| tally_hash[key] = value.sum(&:tally)}
    tally_hash
  end

  ##
  # Gets the total number of downloads for the dataset.
  # @param [String] dataset_key the key of the dataset.
  # @return [Integer] the total number of downloads for the dataset.
  def self.total_downloads(dataset_key)
    DatasetDownloadTally.where(dataset_key: dataset_key).sum :tally
  end

  ##
  # Gets the total number of downloads for the dataset today.
  # @param [String] dataset_key the key of the dataset.
  # @return [Integer] the total number of downloads for the dataset today.
  def self.today_downloads(dataset_key)
    DayFileDownload.where(dataset_key: dataset_key).uniq.pluck(:ip_address).count
  end

  ##
  # Gets the total number of downloads for the dataset today from the same IP address.
  # @param [String] dataset_key the key of the dataset.
  # @param [String] request_ip the IP address of the request.
  # @return [Integer] the total number of downloads for the dataset today from the same IP address.
  def self.ip_downloaded_dataset_today(dataset_key, request_ip)
    filter = "ip_address = ? and dataset_key = ? and download_date = ?"
    DayFileDownload.where([filter, request_ip, dataset_key, Date.current]).count.positive?
  end

  ##
  # Gets the dataset download tallies for the dataset.
  # @param [String] dataset_key the key of the dataset.
  # @return [Array<DatasetDownloadTally>] the dataset download tallies for the dataset.
  def self.dataset_download_tallies(dataset_key)
    DatasetDownloadTally.where(dataset_key: dataset_key)
  end

  ##
  # Gets the dataset download tallies for the dataset that should be public
  # @param [String] dataset_key the key of the dataset.
  # @return [Array<DatasetDownloadTally>] the dataset download tallies for the dataset that should be public.
  def self.public_dataset_download_tallies(dataset_key)
    dataset_download_tallies(dataset_key).select(&:should_be_public?)
  end

  def self.public_downloads_by_dataset_key
    grouped = public_tallies.group_by(&:dataset_key)
  end
end
