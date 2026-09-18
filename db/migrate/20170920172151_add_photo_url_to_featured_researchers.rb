class AddPhotoUrlToFeaturedResearchers < ActiveRecord::Migration[4.2]
  def change
    add_column :featured_researchers, :photo_url, :string
  end
end
