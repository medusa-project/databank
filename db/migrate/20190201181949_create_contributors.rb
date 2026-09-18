class CreateContributors < ActiveRecord::Migration[4.2]
  def change
    create_table :contributors do |t|
      t.integer :dataset_id
      t.string :family_name
      t.string :given_name
      t.string :institution_name
      t.string :identifier
      t.integer :type_of
      t.integer :row_order
      t.string :email
      t.integer :row_position
      t.string :identifier_scheme

      t.timestamps null: false
    end
  end
end
