class RenameTypeForCreator < ActiveRecord::Migration
  def change
    rename_column :creators, :type, :type_of
  end
end
