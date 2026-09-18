class AddKeywordsToDatasets < ActiveRecord::Migration[4.2]
  def change
    add_column :datasets, :keywords, :string
  end
end
