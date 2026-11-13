# frozen_string_literal: true

class AddS3MultipartStateToGoogleDriveImports < ActiveRecord::Migration[8.0]
  def change
    add_column :google_drive_imports, :s3_upload_id, :string
    add_column :google_drive_imports, :s3_uploaded_parts, :jsonb, null: false, default: []
  end
end
