class AddForeignKeyToDatasetDownloadTallies < ActiveRecord::Migration[7.1]
  def change
    add_foreign_key :dataset_download_tallies, :datasets, column: :dataset_key, primary_key: :key
  end
end
