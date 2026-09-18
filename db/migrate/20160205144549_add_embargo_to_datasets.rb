class AddEmbargoToDatasets < ActiveRecord::Migration[4.2]
  def change
    add_column :datasets, :embargo, :string
  end
end
