class CreateSysfileKeys < ActiveRecord::Migration[4.2]
  def change
    create_table :sysfile_keys do |t|
      t.integer :dataset_id
      t.string :storage_root
      t.string :storage_key
      t.string :file_type

      t.timestamps null: false
    end
  end
end
