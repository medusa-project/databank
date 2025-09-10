class CreateCreators < ActiveRecord::Migration
  def change
    create_table :creators do |t|
      t.integer :dataset_id
      t.string :family_name
      t.string :given_name
      t.string :institution_name
      t.string :identifier
      t.string :type
      t.integer :position

      t.timestamps null: false
    end
  end
end
