class AddExpiresToInvitees < ActiveRecord::Migration
  def change
    add_column :invitees, :expires_at, :datetime
  end
end
