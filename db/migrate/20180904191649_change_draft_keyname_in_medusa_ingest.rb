class ChangeDraftKeynameInMedusaIngest < ActiveRecord::Migration
  def change
    rename_column :medusa_ingests, :draft_key, :staging_key
  end
end
