class AddInviteeToIdentities < ActiveRecord::Migration[4.2]
  def change
    add_column :identities, :invitee_id, :integer
  end
end
