class CreateNotes < ActiveRecord::Migration[6.0]
  def change
    create_table :notes do |t|
      t.bigint :dataset_id
      t.string :body
      t.string :author

      t.timestamps
    end
  end
end
