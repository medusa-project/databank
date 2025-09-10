class ChangeDefaultDataciteFlagForDatasets < ActiveRecord::Migration
  def change
    change_column :datasets, :has_datacite_change, :boolean, default: false
  end
end
