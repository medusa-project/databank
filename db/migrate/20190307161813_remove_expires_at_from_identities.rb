class RemoveExpiresAtFromIdentities < ActiveRecord::Migration[4.2]
  def change
    remove_column :identities, :expires_at, :datetime
  end
end
