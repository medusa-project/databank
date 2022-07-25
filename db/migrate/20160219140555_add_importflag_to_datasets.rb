class AddImportflagToDatasets < ActiveRecord::Migration
  def change
    add_column :datasets, :is_import, :boolean, default: false
  end
end
