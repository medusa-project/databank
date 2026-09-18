class RemovePublicationYearFromDatasets < ActiveRecord::Migration[4.2]
  def change
    remove_column :datasets, :publication_year, :string
  end
end
