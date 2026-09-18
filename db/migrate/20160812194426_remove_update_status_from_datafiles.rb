class RemoveUpdateStatusFromDatafiles < ActiveRecord::Migration[4.2]
  def change
    if column_exists?(:datafiles, :upload_status)
      remove_column :datafiles, :upload_status, :string
    end
  end
end
