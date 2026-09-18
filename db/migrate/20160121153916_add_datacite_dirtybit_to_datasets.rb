class AddDataciteDirtybitToDatasets < ActiveRecord::Migration[4.2]
  def change
    add_column :datasets, :has_datacite_change, :boolean, :default => true
  end
end
