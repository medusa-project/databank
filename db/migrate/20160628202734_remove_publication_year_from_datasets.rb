class RemovePublicationYearFromDatasets < ActiveRecord::Migration
  def change
    remove_column :datasets, :publication_year, :string
  end
end
