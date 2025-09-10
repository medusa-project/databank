class CreateTokens < ActiveRecord::Migration
  def change
    create_table :tokens do |t|
      t.string :dataset_key
      t.string :identifier
      t.datetime :expires

      t.timestamps null: false
    end
  end
end
