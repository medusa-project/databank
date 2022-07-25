class AddRowPositionToCreators < ActiveRecord::Migration
  def change
    add_column :creators, :row_position, :integer
  end
end
