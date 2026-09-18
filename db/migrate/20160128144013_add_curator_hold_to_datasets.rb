class AddCuratorHoldToDatasets < ActiveRecord::Migration[4.2]
  def change
    add_column :datasets, :curator_hold, :boolean, default: false
  end
end
