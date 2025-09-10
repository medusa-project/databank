class AddMimeTypeToDatafiles < ActiveRecord::Migration
  def change
    add_column :datafiles, :mime_type, :string
  end
end
