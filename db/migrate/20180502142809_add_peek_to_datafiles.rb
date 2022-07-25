class AddPeekToDatafiles < ActiveRecord::Migration
  def change
    add_column :datafiles, :peek_type, :string
    add_column :datafiles, :peek_text, :text
  end
end
