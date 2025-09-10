class RemoveExpiresAtFromIdentities < ActiveRecord::Migration
  def change
    remove_column :identities, :expires_at, :datetime
  end
end
