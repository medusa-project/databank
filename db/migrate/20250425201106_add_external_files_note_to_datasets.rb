class AddExternalFilesNoteToDatasets < ActiveRecord::Migration[7.2]
  def change
    add_column :datasets, :external_files_note, :text
  end
end
