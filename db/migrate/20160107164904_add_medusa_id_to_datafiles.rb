class AddMedusaIdToDatafiles < ActiveRecord::Migration[4.2]
  def change
    add_column :datafiles, :medusa_id, :string
  end
end
