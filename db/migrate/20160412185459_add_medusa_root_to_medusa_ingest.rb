class AddMedusaRootToMedusaIngest < ActiveRecord::Migration
  def change
    add_column :medusa_ingests, :medusa_dataset_dir, :string
  end
end
