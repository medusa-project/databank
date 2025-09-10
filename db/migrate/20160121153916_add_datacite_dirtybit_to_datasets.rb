class AddDataciteDirtybitToDatasets < ActiveRecord::Migration
  def change
    add_column :datasets, :has_datacite_change, :boolean, :default => true
  end
end
