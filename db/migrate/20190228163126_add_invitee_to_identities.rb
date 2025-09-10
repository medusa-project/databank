class AddInviteeToIdentities < ActiveRecord::Migration
  def change
    add_column :identities, :invitee_id, :integer
  end
end
