class ChangeUploadFileSizeLimitForDatafiles < ActiveRecord::Migration
  def change
    change_column :datafiles, :upload_file_size, :integer, limit: 8
  end
end
