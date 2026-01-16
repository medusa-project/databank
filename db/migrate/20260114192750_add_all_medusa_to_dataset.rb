class AddAllMedusaToDataset < ActiveRecord::Migration[7.2]
  def change
    add_column :datasets, :all_medusa, :boolean
  end
end
