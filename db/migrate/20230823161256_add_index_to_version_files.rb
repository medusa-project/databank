class AddIndexToVersionFiles < ActiveRecord::Migration[7.0]
  def change
    add_index :version_files, :datafile_id, unique: true
  end
end
