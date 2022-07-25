class RemoveUpdateStatusFromDatafiles < ActiveRecord::Migration
  def change
    if column_exists?(:datafiles, :upload_status)
      remove_column :datafiles, :upload_status, :string
    end
  end
end
