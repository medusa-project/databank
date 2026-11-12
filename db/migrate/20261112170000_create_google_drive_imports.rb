# frozen_string_literal: true

class CreateGoogleDriveImports < ActiveRecord::Migration[8.0]
  def change
    create_table :google_drive_connections do |t|
      t.references :user, null: false, foreign_key: true, type: :integer
      t.references :dataset, null: false, foreign_key: true, type: :integer
      t.text :encrypted_credentials
      t.datetime :expires_at, null: false
      t.timestamps
    end
    add_index :google_drive_connections, :expires_at

    create_table :google_drive_imports do |t|
      t.references :user, null: false, foreign_key: true, type: :integer
      t.references :dataset, null: false, foreign_key: true, type: :integer
      t.references :google_drive_connection, null: false, foreign_key: true
      t.references :datafile, foreign_key: {on_delete: :nullify}, type: :integer, index: false
      t.string :status, null: false, default: "queued"
      t.jsonb :source_metadata, null: false, default: {}
      t.bigint :bytes_downloaded, null: false, default: 0
      t.text :error_message
      t.timestamps
    end
    add_index :google_drive_imports, :status
    add_index :google_drive_imports, :datafile_id, unique: true, name: "unique_drive_import_datafile"
  end
end
