class RemoveHasDataciteChangeFromDatasets < ActiveRecord::Migration
  def change
    remove_column :datasets, :has_datacite_change
  end
end
