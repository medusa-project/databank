class AddPublicationStateToDatasets < ActiveRecord::Migration[4.2]
  def change
    add_column :datasets, :publication_state, :string, :default => 'draft'
  end
end
