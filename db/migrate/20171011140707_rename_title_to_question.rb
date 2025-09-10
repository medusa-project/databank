class RenameTitleToQuestion < ActiveRecord::Migration
  def change
    rename_column :featured_researchers, :title, :question
  end
end
