json.extract! ingest_response, :id, :as_text, :status, :response_time, :staging_key, :medusa_key, :uuid, :created_at, :updated_at
json.url ingest_response_url(ingest_response, format: :json)
