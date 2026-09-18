class AddMedusaRootToDatasets < ActiveRecord::Migration[4.2]
  def change
    add_column :datasets, :medusa_dataset_dir, :string
  end
end
