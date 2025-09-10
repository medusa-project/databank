json.extract! extractor_error, :id, :extractor_response_id, :error_type, :report, :created_at, :updated_at
json.url extractor_error_url(extractor_error, format: :json)
