class RenameSysfile < ActiveRecord::Migration[4.2]
  def change
    rename_table :sysfile_keys, :system_files
  end
end
