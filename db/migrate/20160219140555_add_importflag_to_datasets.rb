class AddImportflagToDatasets < ActiveRecord::Migration[4.2]
  def change
    add_column :datasets, :is_import, :boolean, default: false
  end
end
