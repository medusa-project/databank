class AddSizeToDatafiles < ActiveRecord::Migration[4.2]
  def change
    add_column :datafiles, :upload_file_size, :integer
  end
end
