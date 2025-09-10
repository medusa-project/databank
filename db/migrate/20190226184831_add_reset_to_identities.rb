class AddResetToIdentities < ActiveRecord::Migration
  def change
    add_column :identities, :reset_digest, :string
  end
end
