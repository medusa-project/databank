class AddPhotoUrlToFeaturedResearchers < ActiveRecord::Migration
  def change
    add_column :featured_researchers, :photo_url, :string
  end
end
