class CreateReviewRequests < ActiveRecord::Migration
  def change
    create_table :review_requests do |t|
      t.string :dataset_key
      t.datetime :requested_at

      t.timestamps null: false
    end
  end
end
