class AddCuratorHoldToDatasets < ActiveRecord::Migration
  def change
    add_column :datasets, :curator_hold, :boolean, default: false
  end
end
