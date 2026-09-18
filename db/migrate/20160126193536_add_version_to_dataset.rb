class AddVersionToDataset < ActiveRecord::Migration[4.2]
  def change
    add_column :datasets, :version, :string, default: "1"
  end
end
