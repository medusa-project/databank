class AddSuppressChangelogToDatasets < ActiveRecord::Migration[4.2]
  def change
    add_column :datasets, :suppress_changelog, :boolean, default: unquoted_false
  end
end
