class AddDatasetVersionToDatasets < ActiveRecord::Migration[4.2]
  def change
    add_column :datasets, :dataset_version, :string, default: "1"
  end
end
