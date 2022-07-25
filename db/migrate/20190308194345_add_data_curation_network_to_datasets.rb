class AddDataCurationNetworkToDatasets < ActiveRecord::Migration
  def change
    add_column :datasets, :data_curation_network, :boolean, default: false, null: false
  end
end
