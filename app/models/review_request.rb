# frozen_string_literal: true

class ReviewRequest < ApplicationRecord
  def dataset
    Dataset.find_by(key: dataset_key)
  end
end
