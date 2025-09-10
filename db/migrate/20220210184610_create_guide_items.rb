class CreateGuideItems < ActiveRecord::Migration[6.1]
  def change
    create_table :guide_items do |t|
      t.integer :section_id
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
