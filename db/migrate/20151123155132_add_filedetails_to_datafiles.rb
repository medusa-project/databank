class AddFiledetailsToDatafiles < ActiveRecord::Migration[4.2]
  def change
    add_column :datafiles, :box_filename, :string
    add_column :datafiles, :box_filesize_display, :string
  end
end
