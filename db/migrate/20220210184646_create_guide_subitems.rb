class CreateGuideSubitems < ActiveRecord::Migration[6.1]
  def change
    create_table :guide_subitems do |t|
      t.integer :item_id
      t.string :anchor
      t.string :label
      t.integer :ordinal
      t.string :heading
      t.string :body
      t.boolean :public, default: false

      t.timestamps
    end
  end
end
