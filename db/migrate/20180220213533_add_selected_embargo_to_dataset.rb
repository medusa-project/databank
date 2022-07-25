class AddSelectedEmbargoToDataset < ActiveRecord::Migration
  def change
    add_column :datasets, :selected_embargo, :string
    add_column :datasets, :selected_release_date, :date
  end
end
