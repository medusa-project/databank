class AddGraniteLinkToDatasets < ActiveRecord::Migration[7.2]
  def change
    add_column :datasets, :granite_link, :string
  end
end
