class RemoveVersionFromDataset < ActiveRecord::Migration
  def change
    remove_column :datasets, :version
  end
end
