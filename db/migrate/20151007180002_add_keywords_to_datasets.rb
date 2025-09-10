class AddKeywordsToDatasets < ActiveRecord::Migration
  def change
    add_column :datasets, :keywords, :string
  end
end
