# frozen_string_literal: true

class CreateBoxImports < ActiveRecord::Migration[8.0]
  def change
    create_table :box_connections do |t|
      t.references :user, type: :integer, null: false, foreign_key: true
      t.references :dataset, type: :integer, null: false, foreign_key: true
      t.text :encrypted_credentials
      t.datetime :expires_at, null: false
      t.timestamps
    end
    add_index :box_connections, :expires_at
    create_table :box_imports do |t|
      t.references :user, type: :integer, null: false, foreign_key: true
      t.references :dataset, type: :integer, null: false, foreign_key: true
      t.references :box_connection, null: false, foreign_key: true
      t.references :datafile, type: :integer, foreign_key: {on_delete: :nullify}, index: {unique: true}
      t.string :status, null: false, default: "queued"
      t.jsonb :source_metadata, null: false, default: {}
      t.bigint :bytes_downloaded, null: false, default: 0
      t.text :error_message
      t.string :s3_upload_id
      t.jsonb :s3_uploaded_parts, null: false, default: []
      t.timestamps
    end
    add_index :box_imports, :status
  end
end
