class AddResetSentAtToIdentity < ActiveRecord::Migration
  def change
    add_column :identities, :reset_sent_at, :datetime
  end
end
