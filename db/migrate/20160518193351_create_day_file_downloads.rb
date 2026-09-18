class CreateDayFileDownloads < ActiveRecord::Migration[4.2]
  def change
    create_table :day_file_downloads do |t|
      t.string :ip_address
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
