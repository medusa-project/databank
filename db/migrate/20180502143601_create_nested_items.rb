class CreateNestedItems < ActiveRecord::Migration
  def change
    create_table :nested_items do |t|
      t.integer :datafile_id
      t.integer :parent_id
      t.string :item_name
      t.string :media_type
      t.integer :size

      t.timestamps null: false
    end
  end
end
