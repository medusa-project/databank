# frozen_string_literal: true

##
# Datafile::Downloadable
# ------------------
# This module is included in the Datafile model to provide methods for handling the download of the datafile
module Datafile::Downloadable
  extend ActiveSupport::Concern

  ##
  # @return [ActiveRecord::Relation] the FileDownloadTally records for this datafile
  def file_download_tallies
    FileDownloadTally.where(file_web_id: self.web_id)
  end

  ##
  # @return [ActiveRecord::Relation] the DayFileDownload records for this datafile
  def total_downloads
    FileDownloadTally.where(file_web_id: self.web_id).sum :tally
  end

  ##
  # Record a download of the datafile
  # @param [String] request_ip the request ip
  def record_download(request_ip)
    return nil if Robot.exists?(address: request_ip)

    return nil if Databank::PublicationState::DRAFT_ARRAY.include?(dataset.publication_state)

    return nil if dataset.release_date.nil?

    return nil if Date.current < dataset.release_date

    unless dataset.ip_downloaded_dataset_today(request_ip)

      day_ds_download_set = DatasetDownloadTally.where(["dataset_key= ? and download_date = ?",
                                                        dataset.key,
                                                        Date.current])

      if day_ds_download_set.count == 1

        today_dataset_download = day_ds_download_set.first
        today_dataset_download.tally = today_dataset_download.tally + 1
        today_dataset_download.save
      elsif day_ds_download_set.count.zero?
        DatasetDownloadTally.create(tally:         1,
                                    download_date: Date.current,
                                    dataset_key:   dataset.key,
                                    doi:           dataset.identifier)
      else
        Rails.logger.warn "wrong # dataset tally download of #{self.web_id} on #{Date.current} ip: #{request_ip}"
      end

    end

    return nil if ip_downloaded_file_today(request_ip)

    DayFileDownload.create(ip_address:    request_ip,
                           download_date: Date.current,
                           file_web_id:   self.web_id,
                           filename:      bytestream_name,
                           dataset_key:   dataset.key,
                           doi:           dataset.identifier)

    day_df_download_set = FileDownloadTally.where(["file_web_id = ? and download_date = ?",
                                                   self.web_id,
                                                   Date.current])

    if day_df_download_set.count == 1
      today_file_download = day_df_download_set.first
      today_file_download.tally = today_file_download.tally + 1
      today_file_download.save
    elsif day_df_download_set.count.zero?
      FileDownloadTally.create(tally:         1,
                               download_date: Date.current,
                               dataset_key:   dataset.key,
                               doi:           dataset.identifier,
                               file_web_id:   web_id,
                               filename:      bytestream_name)
    else
      Rails.logger.warn "wrong # of file tally download of #{web_id} on #{Date.current} ip: #{request_ip}"
    end
  end

  ##
  # @param [String] request_ip a request ip
  # @return [Boolean] whether the datafile has been downloaded by the given ip today
  def ip_downloaded_file_today(request_ip)
    DayFileDownload.where(["ip_address = ? and file_web_id = ? and download_date = ?",
                           request_ip,
                           self.web_id,
                           Date.current]).count > 0
  end

  delegate :key, to: :dataset, prefix: true

  ##
  # @return [String] the datafile's storage key in the target root for use in Medusa Ingests
  def target_key
    "#{dataset.dirname}/dataset_files/#{binary_name}"
  end

end
