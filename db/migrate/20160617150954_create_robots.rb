class CreateRobots < ActiveRecord::Migration
  def change
    create_table :robots do |t|
      t.string :source
      t.string :address

      t.timestamps null: false
    end
  end
end
