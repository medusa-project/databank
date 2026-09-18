class AddRowPositionToCreators < ActiveRecord::Migration[4.2]
  def change
    add_column :creators, :row_position, :integer
  end
end
