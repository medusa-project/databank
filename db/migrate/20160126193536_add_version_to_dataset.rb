class AddVersionToDataset < ActiveRecord::Migration
  def change
    add_column :datasets, :version, :string, default: "1"
  end
end
