class ChangeDraftKeynameInMedusaIngest < ActiveRecord::Migration[4.2]
  def change
    rename_column :medusa_ingests, :draft_key, :staging_key
  end
end
