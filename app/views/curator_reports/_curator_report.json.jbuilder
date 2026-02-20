json.extract! curator_report, :id, :requestor_name, :requestor_email, :report_type, :storage_root, :storage_key, :notes, :created_at, :updated_at
json.url curator_report_url(curator_report, format: :json)
