class ChangeDefaultDatasetVersion < ActiveRecord::Migration
  def change
    change_column_default :datasets, :version, 1
  end
end
