class AddResetToIdentities < ActiveRecord::Migration[4.2]
  def change
    add_column :identities, :reset_digest, :string
  end
end
