class AddFiledetailsToDatafiles < ActiveRecord::Migration
  def change
    add_column :datafiles, :box_filename, :string
    add_column :datafiles, :box_filesize_display, :string
  end
end
