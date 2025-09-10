class AddAgreementToDatasets < ActiveRecord::Migration
  def change
    add_column :datasets, :have_permission, :string, default: "no"
    add_column :datasets, :removed_private, :string, default: "no"
    add_column :datasets, :agree, :string, default: "no"
  end
end
