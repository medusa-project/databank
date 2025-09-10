class AddAdmin < ActiveRecord::Migration
  def change
    create_table :admin do |t|
      t.text :read_only_alert
      t.integer :singleton_guard

      t.timestamps null: false
    end
    add_index(:admin, :singleton_guard, unique: true)
  end

end