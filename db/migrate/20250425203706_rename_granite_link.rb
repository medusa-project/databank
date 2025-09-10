class RenameGraniteLink < ActiveRecord::Migration[7.2]
  def change
    # in the datasets table, rename granite_link to external_files_link
    rename_column :datasets, :granite_link, :external_files_link
  end
end
