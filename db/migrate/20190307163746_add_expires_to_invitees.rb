class AddExpiresToInvitees < ActiveRecord::Migration[4.2]
  def change
    add_column :invitees, :expires_at, :datetime
  end
end
