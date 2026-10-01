json.extract! review_request, :id, :dataset_key, :requested_at, :requestor_name, :requestor_email, :created_at, :updated_at
json.url review_request_url(review_request, format: :json)
