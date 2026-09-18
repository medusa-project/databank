class AddPubstateToFeaturedResearchers < ActiveRecord::Migration[4.2]
  def change
    add_column :featured_researchers, :is_active, :boolean
  end
end
