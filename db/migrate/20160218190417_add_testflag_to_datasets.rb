class AddTestflagToDatasets < ActiveRecord::Migration[4.2]
  def change
    add_column :datasets, :is_test, :boolean, default: false
  end
end
