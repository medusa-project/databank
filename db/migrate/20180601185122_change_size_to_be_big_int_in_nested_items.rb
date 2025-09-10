class ChangeSizeToBeBigIntInNestedItems < ActiveRecord::Migration
  def change
    change_column :nested_items, :size, :int8, :limit => 8
  end
end
