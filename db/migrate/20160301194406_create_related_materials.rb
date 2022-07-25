class CreateRelatedMaterials < ActiveRecord::Migration
  def change
    create_table :related_materials do |t|
      t.string :materialType
      t.string :availability
      t.string :link
      t.string :uri
      t.string :uri_type
      t.text :citation
      t.integer :dataset_id

      t.timestamps null: false
    end
  end
end
