class CreateRestorationEvents < ActiveRecord::Migration[4.2]
  def change
    create_table :restoration_events do |t|
      t.text :note

      t.timestamps null: false
    end
  end
end
