class AddVersionCommentToDataset < ActiveRecord::Migration[4.2]
  def change
    add_column :datasets, :version_comment, :text
  end
end
