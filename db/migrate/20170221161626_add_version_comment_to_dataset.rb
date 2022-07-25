class AddVersionCommentToDataset < ActiveRecord::Migration
  def change
    add_column :datasets, :version_comment, :text
  end
end
