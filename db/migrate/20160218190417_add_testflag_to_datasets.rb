class AddTestflagToDatasets < ActiveRecord::Migration
  def change
    add_column :datasets, :is_test, :boolean, default: false
  end
end
