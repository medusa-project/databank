# frozen_string_literal: true

##
# This module supports tracking downloads of datasets.
# It is included in the Dataset model.

module Dataset::Downloadable
  extend ActiveSupport::Concern

  ##
  # @return [Integer] the number of downloads for the dataset today
  # multiple downloads from the same IP address are counted only once
  def today_downloads
    DayFileDownload.where(dataset_key: key).uniq.pluck(:ip_address).count
  end

  ##
  # @return [Integer] the total number of downloads for the dataset
  def total_downloads
    DatasetDownloadTally.where(dataset_key: key).sum(&:tally)
  end

  ##
  # @return [Integer] the total number of downloads for the dataset that should be public
  def public_downloads
    DatasetDownloadTally.public_dataset_download_tallies(self.key).sum(&:tally)
  end

  ##
  # @return [Integer] the total number of downloads for the dataset today
  def dataset_download_tallies
    DatasetDownloadTally.where(dataset_key: key)
  end

  ##
  # @param [String] request_ip the IP address of the request
  # @return [Integer] the total number of downloads for the dataset today from the same IP address
  def ip_downloaded_dataset_today(request_ip)
    filter = "ip_address = ? and dataset_key = ? and download_date = ?"
    DayFileDownload.where([filter, request_ip, key, Date.current]).count.positive?
  end

end
