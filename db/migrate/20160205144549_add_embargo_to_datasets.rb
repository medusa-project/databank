class AddEmbargoToDatasets < ActiveRecord::Migration
  def change
    add_column :datasets, :embargo, :string
  end
end
