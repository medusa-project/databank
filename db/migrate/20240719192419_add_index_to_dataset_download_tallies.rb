class AddIndexToDatasetDownloadTally < ActiveRecord::Migration[7.1]
  def change
    add_index :dataset_download_tallies, :dataset_key
  end
end
