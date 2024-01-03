class AddNestedUpdatedAtToDatasets < ActiveRecord::Migration[7.1]
  def change
    add_column :datasets, :nested_updated_at, :datetime
  end
end
