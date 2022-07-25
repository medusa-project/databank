class CreateIngestResponses < ActiveRecord::Migration
  def change
    create_table :ingest_responses do |t|
      t.text :as_text
      t.string :status
      t.datetime :response_time
      t.string :staging_key
      t.string :medusa_key
      t.string :uuid

      t.timestamps null: false
    end
  end
end
