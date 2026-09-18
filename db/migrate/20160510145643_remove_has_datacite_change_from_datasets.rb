class RemoveHasDataciteChangeFromDatasets < ActiveRecord::Migration[4.2]
  def change
    remove_column :datasets, :has_datacite_change
  end
end
