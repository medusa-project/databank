class AddInitiatedToVersionFiles < ActiveRecord::Migration[7.0]
  def change
    add_column :version_files, :initiated, :boolean, default: false
  end
end
