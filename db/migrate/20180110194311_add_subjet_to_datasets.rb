class AddSubjetToDatasets < ActiveRecord::Migration[4.2]
  def change
    add_column :datasets, :subject, :string
  end
end
