class RenameSysfile < ActiveRecord::Migration
  def change
    rename_table :sysfile_keys, :system_files
  end
end
