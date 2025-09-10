class ChangeResourceIdTypeInUserAbilities < ActiveRecord::Migration[5.2]
  def change
    remove_column :user_abilities, :resource_id, :string
    add_column :user_abilities, :resource_id, :integer
  end
end
