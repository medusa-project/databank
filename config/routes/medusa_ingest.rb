resources :ingest_responses
resources :medusa_ingests do
  collection do
    post "remove_draft_if_in_medusa"
  end
end