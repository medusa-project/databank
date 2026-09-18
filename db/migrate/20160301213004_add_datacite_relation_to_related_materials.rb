class AddDataciteRelationToRelatedMaterials < ActiveRecord::Migration[4.2]
  def change
    add_column :related_materials, :datacite_list, :string
  end
end
