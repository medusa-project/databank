class AddSizeToDatafiles < ActiveRecord::Migration
  def change
    add_column :datafiles, :upload_file_size, :integer
  end
end
