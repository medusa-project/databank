class AddPublicationStateToDatasets < ActiveRecord::Migration
  def change
    add_column :datasets, :publication_state, :string, :default => 'draft'
  end
end
