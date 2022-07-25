class AddPubstateToFeaturedResearchers < ActiveRecord::Migration
  def change
    add_column :featured_researchers, :is_active, :boolean
  end
end
