class AddInGlobusToDatafile < ActiveRecord::Migration[7.2]
  def change
    add_column :datafiles, :in_globus, :boolean
  end
end
