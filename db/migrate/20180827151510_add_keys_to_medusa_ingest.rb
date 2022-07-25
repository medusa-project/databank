class AddKeysToMedusaIngest < ActiveRecord::Migration
  def change
    add_column :medusa_ingests, :draft_key, :string
    add_column :medusa_ingests, :medusa_key, :string
  end
end
