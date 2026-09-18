class ChangeUploadFileSizeLimitForDatafiles < ActiveRecord::Migration[4.2]
  def change
    change_column :datafiles, :upload_file_size, :integer, limit: 8
  end
end
