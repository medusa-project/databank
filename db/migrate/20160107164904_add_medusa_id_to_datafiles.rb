class AddMedusaIdToDatafiles < ActiveRecord::Migration
  def change
    add_column :datafiles, :medusa_id, :string
  end
end
