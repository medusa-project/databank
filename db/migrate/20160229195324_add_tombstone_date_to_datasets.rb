class AddTombstoneDateToDatasets < ActiveRecord::Migration
  def change
    add_column :datasets, :tombstone_date, :date
  end
end
