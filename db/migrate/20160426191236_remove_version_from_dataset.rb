class RemoveVersionFromDataset < ActiveRecord::Migration[4.2]
  def change
    remove_column :datasets, :version
  end
end
