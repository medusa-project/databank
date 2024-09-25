class AddIndexesToFileDownloadTallies < ActiveRecord::Migration[7.1]
  def change
    add_index :file_download_tallies, :dataset_key
    add_index :file_download_tallies, :file_web_id
  end
end
