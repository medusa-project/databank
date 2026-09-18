class ChangeMedusaKeynameInMedusaIngest < ActiveRecord::Migration[4.2]
  def change
    rename_column :medusa_ingests, :medusa_key, :target_key
  end
end
