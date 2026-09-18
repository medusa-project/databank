class RenamePositionToRowOrder < ActiveRecord::Migration[4.2]
  def change
    rename_column :creators, :position, :row_order
  end
end
