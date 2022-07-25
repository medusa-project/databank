# frozen_string_literal: true

class DatasetDownloadTally < ApplicationRecord
  def should_be_public?
    return false if doi.empty?

    dataset = Dataset.find_by(key: dataset_key)
    return false unless dataset.metadata_public?

    return false if dataset.is_test

    return false unless created_at > dataset.dataset.release_datetime

    true
  end

  def self.public_tallies
    DatasetDownloadTally.all.select(&:should_be_public?)
  end
end
