class AddDatasetVersionToDatasets < ActiveRecord::Migration
  def change
    add_column :datasets, :dataset_version, :string, default: "1"
  end
end
