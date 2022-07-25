class AddActivationToIdentities < ActiveRecord::Migration
  def change
    add_column :identities, :activation_digest, :string
    add_column :identities, :activated, :boolean, default: false
    add_column :identities, :activated_at, :datetime
    add_column :identities, :expires_at, :datetime
  end
end
