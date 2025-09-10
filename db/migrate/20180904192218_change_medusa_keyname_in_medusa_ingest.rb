class ChangeMedusaKeynameInMedusaIngest < ActiveRecord::Migration
  def change
    rename_column :medusa_ingests, :medusa_key, :target_key
  end
end
