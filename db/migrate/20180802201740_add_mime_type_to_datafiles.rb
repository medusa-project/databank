class AddMimeTypeToDatafiles < ActiveRecord::Migration[4.2]
  def change
    add_column :datafiles, :mime_type, :string
  end
end
