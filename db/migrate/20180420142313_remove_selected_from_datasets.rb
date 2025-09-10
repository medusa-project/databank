class RemoveSelectedFromDatasets < ActiveRecord::Migration
  def change
    remove_column :datasets, :selected_embargo, :string
    remove_column :datasets, :selected_release_date, :string
  end
end
