json.extract! note, :id, :dataset_id, :body, :author, :created_at, :updated_at
json.url note_url(note, format: :json)
