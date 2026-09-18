class CreateFunders < ActiveRecord::Migration[4.2]
  def change
    create_table :funders do |t|
      t.string :name
      t.string :identifier
      t.string :identifier_scheme
      t.string :grant
      t.integer :dataset_id

      t.timestamps null: false
    end
  end
end
