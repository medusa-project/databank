class ChangeDefaultDatasetVersion < ActiveRecord::Migration[4.2]
  def change
    change_column_default :datasets, :version, 1
  end
end
