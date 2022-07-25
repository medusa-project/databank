class CreateMedusaIngests < ActiveRecord::Migration
  def change
    create_table :medusa_ingests do |t|
      t.string :idb_class
      t.string :idb_identifier
      t.string :staging_path
      t.string :request_status
      t.string :medusa_path
      t.string :medusa_uuid
      t.timestamp :response_time
      t.string :error_text

      t.timestamps null: false
    end
  end
end
