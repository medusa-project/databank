class AddMedusaRootToMedusaIngest < ActiveRecord::Migration[4.2]
  def change
    add_column :medusa_ingests, :medusa_dataset_dir, :string
  end
end
