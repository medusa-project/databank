# frozen_string_literal: true

class FileDownloadTally < ApplicationRecord
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

  def self.public_tallies
    FileDownloadTally.all.select(&:should_be_public?)
  end
end
