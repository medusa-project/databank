class AddRequestorToReviewRequests < ActiveRecord::Migration[4.2]
  def change
    add_column :review_requests, :requestor_name, :string
    add_column :review_requests, :requestor_email, :string
  end
end