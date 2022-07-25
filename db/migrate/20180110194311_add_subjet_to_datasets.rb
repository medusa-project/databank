class AddSubjetToDatasets < ActiveRecord::Migration
  def change
    add_column :datasets, :subject, :string
  end
end
