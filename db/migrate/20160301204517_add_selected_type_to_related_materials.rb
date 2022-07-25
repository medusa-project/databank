class AddSelectedTypeToRelatedMaterials < ActiveRecord::Migration
  def change
    add_column :related_materials, :selected_type, :string
  end
end
