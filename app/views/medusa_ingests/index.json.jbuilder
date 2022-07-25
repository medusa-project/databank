json.array!(@medusa_ingests) do |medusa_ingest|
  json.extract! medusa_ingest, :id, :idb_class, :idb_identifier, :staging_path, :request_status, :medusa_path, :medusa_uuid, :response_time, :error_text
  json.url medusa_ingest_url(medusa_ingest, format: :json)
end
