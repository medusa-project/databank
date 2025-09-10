class AddUploadStatusToDatafiles < ActiveRecord::Migration
  def change
    add_column :datafiles, :upload_status, :string
  end
end
