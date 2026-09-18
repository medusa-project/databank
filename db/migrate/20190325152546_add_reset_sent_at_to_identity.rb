class AddResetSentAtToIdentity < ActiveRecord::Migration[4.2]
  def change
    add_column :identities, :reset_sent_at, :datetime
  end
end
