class AddTombstoneDateToDatasets < ActiveRecord::Migration[4.2]
  def change
    add_column :datasets, :tombstone_date, :date
  end
end
