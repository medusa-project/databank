class FixMaterialTypeColumnName < ActiveRecord::Migration[4.2]
  def change
    rename_column :related_materials, :materialType, :material_type
  end
end
