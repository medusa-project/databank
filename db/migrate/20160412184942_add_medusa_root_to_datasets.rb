class AddMedusaRootToDatasets < ActiveRecord::Migration
  def change
    add_column :datasets, :medusa_dataset_dir, :string
  end
end
