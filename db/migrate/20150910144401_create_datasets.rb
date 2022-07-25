class CreateDatasets < ActiveRecord::Migration
  def change
    create_table :datasets do |t|
      t.string :key, :null => false
      t.string :title
      t.string :creator_text
      t.string :identifier
      t.string :publisher
      t.string :publication_year
      t.string :description
      t.string :license
      t.string :depositor_name
      t.string :depositor_email
      t.boolean :complete
      t.string :corresponding_creator_name
      t.string :corresponding_creator_email
      t.timestamps null: false
      t.index :key, unique: true
    end
  end
end
