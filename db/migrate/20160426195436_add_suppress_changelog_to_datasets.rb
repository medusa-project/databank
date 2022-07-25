class AddSuppressChangelogToDatasets < ActiveRecord::Migration
  def change
    add_column :datasets, :suppress_changelog, :boolean, default: unquoted_false
  end
end
