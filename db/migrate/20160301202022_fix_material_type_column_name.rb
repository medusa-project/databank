class FixMaterialTypeColumnName < ActiveRecord::Migration
  def change
    rename_column :related_materials, :materialType, :material_type
  end
end
