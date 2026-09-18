class RenameTypeForCreator < ActiveRecord::Migration[4.2]
  def change
    rename_column :creators, :type, :type_of
  end
end
