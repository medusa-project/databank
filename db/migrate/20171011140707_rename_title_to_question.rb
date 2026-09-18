class RenameTitleToQuestion < ActiveRecord::Migration[4.2]
  def change
    rename_column :featured_researchers, :title, :question
  end
end
