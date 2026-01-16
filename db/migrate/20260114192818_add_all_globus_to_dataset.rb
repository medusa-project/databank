class AddAllGlobusToDataset < ActiveRecord::Migration[7.2]
  def change
    add_column :datasets, :all_globus, :boolean
  end
end
