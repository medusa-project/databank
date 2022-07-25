class CreateDatafiles < ActiveRecord::Migration
  def change
    create_table :datafiles do |t|
      t.string :description
      t.string :binary
      t.string :web_id
      t.integer :dataset_id

      t.timestamps null: false
    end
  end
end
