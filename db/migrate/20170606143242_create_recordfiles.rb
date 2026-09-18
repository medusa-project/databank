class CreateRecordfiles < ActiveRecord::Migration[4.2]
  def change
    create_table :recordfiles do |t|
      t.integer :dataset_id
      t.string :binary
      t.string :web_id
      t.string :medusa_id
      t.string :medusa_path
      t.string :binary_name
      t.integer :binary_size

      t.timestamps null: false
    end
  end
end
