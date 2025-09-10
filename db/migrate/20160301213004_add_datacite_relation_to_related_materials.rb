class AddDataciteRelationToRelatedMaterials < ActiveRecord::Migration
  def change
    add_column :related_materials, :datacite_list, :string
  end
end
