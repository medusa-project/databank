class CreateDefinitions < ActiveRecord::Migration[4.2]
  def change
    create_table :definitions do |t|
      t.string :term
      t.string :meaning

      t.timestamps null: false
    end
  end
end
