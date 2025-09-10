class CreateUserAbilities < ActiveRecord::Migration
  def change
    create_table :user_abilities do |t|
      t.integer :dataset_id
      t.string :user_name
      t.string :user_email
      t.string :ability

      t.timestamps null: false
    end
  end
end
