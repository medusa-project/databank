class AddOrgCreatorsToDatasets < ActiveRecord::Migration
  def change
    add_column :datasets, :org_creators, :boolean, default: FALSE
  end
end
