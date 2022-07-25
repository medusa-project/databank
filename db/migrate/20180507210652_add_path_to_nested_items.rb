class AddPathToNestedItems < ActiveRecord::Migration
  def change
    add_column :nested_items, :item_path, :string
    add_column :nested_items, :is_directory, :boolean
  end
end
