class CreateRobots < ActiveRecord::Migration[4.2]
  def change
    create_table :robots do |t|
      t.string :source
      t.string :address

      t.timestamps null: false
    end
  end
end
