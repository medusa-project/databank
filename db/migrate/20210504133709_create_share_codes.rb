class CreateShareCodes < ActiveRecord::Migration[6.1]
  def change
    create_table :share_codes do |t|
      t.string :code
      t.int :dataset_id

      t.timestamps
    end
  end
end
