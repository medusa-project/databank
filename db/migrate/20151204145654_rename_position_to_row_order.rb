class RenamePositionToRowOrder < ActiveRecord::Migration
  def change
    rename_column :creators, :position, :row_order
  end
end
