class CreateFileDownloadTallies < ActiveRecord::Migration[4.2]
  def change
    create_table :file_download_tallies do |t|
      t.string :file_web_id
      t.string :filename
      t.string :dataset_key
      t.string :doi
      t.date :download_date
      t.integer :tally

      t.timestamps null: false
    end
  end
end
