class CreateDatasetDownloadTallies < ActiveRecord::Migration
  def change
    create_table :dataset_download_tallies do |t|
      t.string :dataset_key
      t.string :doi
      t.date :download_date
      t.integer :tally

      t.timestamps null: false
    end
  end
end
