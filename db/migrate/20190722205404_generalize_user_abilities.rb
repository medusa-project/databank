class GeneralizeUserAbilities < ActiveRecord::Migration[5.2]
  def change
    change_table :user_abilities do |t|
      t.remove :dataset_id, :user_name, :user_email
      t.string :user_provider
      t.string :user_uid
      t.string :resource_type
      t.string :resource_id
    end
  end
end
