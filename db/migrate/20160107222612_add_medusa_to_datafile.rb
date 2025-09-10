class AddMedusaToDatafile < ActiveRecord::Migration
  def change
    add_column :datafiles, :medusa_path, :string
    add_column :datafiles, :binary_name, :string
    add_column :datafiles, :binary_size, :integer, limit: 8
  end
end
