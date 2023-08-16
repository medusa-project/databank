class AddNoteToRelatedMaterial < ActiveRecord::Migration[7.0]
  def change
    add_column :related_materials, :note, :text
    add_column :related_materials, :feature, :boolean
  end
end
