class RemoveGroupFromInvitees < ActiveRecord::Migration[5.2]
  def change
    remove_column :invitees, :group, :string
  end
end
