class AddSelectedTypeToRelatedMaterials < ActiveRecord::Migration[4.2]
  def change
    add_column :related_materials, :selected_type, :string
  end
end
