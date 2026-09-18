class CreateRestorationIdMaps < ActiveRecord::Migration[4.2]
  def change
    create_table :restoration_id_maps do |t|
      t.string :id_class
      t.integer :old_id
      t.integer :new_id
      t.integer :restoration_event_id

      t.timestamps null: false
    end
  end
end
