class ChangeDefaultDataciteFlagForDatasets < ActiveRecord::Migration[4.2]
  def change
    change_column :datasets, :has_datacite_change, :boolean, default: false
  end
end
