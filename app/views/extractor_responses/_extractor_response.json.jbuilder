json.extract! extractor_response, :id, :extractor_task_id, :web_id, :status, :peek_type, :peek_text, :created_at, :updated_at
json.url extractor_response_url(extractor_response, format: :json)
