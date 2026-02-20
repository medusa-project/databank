class AddModifiedToReviewRequest < ActiveRecord::Migration[7.2]
  def change
    add_column :review_requests, :modified, :boolean, default: false
  end
end
