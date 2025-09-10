class AddButtonUrlsToFeaturedResearchers < ActiveRecord::Migration
  def change
    add_column :featured_researchers, :dataset_url, :string
    add_column :featured_researchers, :article_url, :string
  end
end
