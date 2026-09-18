class AddOrgCreatorsToDatasets < ActiveRecord::Migration[4.2]
  def change
    add_column :datasets, :org_creators, :boolean, default: false
  end
end
