class CreateGuideSections < ActiveRecord::Migration[6.1]
  def change
    create_table :guide_sections do |t|
      t.string :anchor
      t.string :label
      t.integer :ordinal
      t.boolean :public, default: false

      t.timestamps
    end
  end
end
