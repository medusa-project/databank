class AddStorageToDatafiles < ActiveRecord::Migration[4.2]
  def change
    add_column :datafiles, :storage_root, :string
    add_column :datafiles, :storage_prefix, :string
    add_column :datafiles, :storage_key, :string
  end
end
