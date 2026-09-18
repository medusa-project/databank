class AddPeekToDatafiles < ActiveRecord::Migration[4.2]
  def change
    add_column :datafiles, :peek_type, :string
    add_column :datafiles, :peek_text, :text
  end
end
