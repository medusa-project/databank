class CreateRestorationEvents < ActiveRecord::Migration
  def change
    create_table :restoration_events do |t|
      t.text :note

      t.timestamps null: false
    end
  end
end
