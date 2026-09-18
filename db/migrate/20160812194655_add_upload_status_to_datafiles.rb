class AddUploadStatusToDatafiles < ActiveRecord::Migration[4.2]
  def change
    add_column :datafiles, :upload_status, :string
  end
end
