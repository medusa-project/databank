resources :datafiles do
  member do
    get "download"
    get "download_no_record"
    get 'filepath', defaults: {format: 'json'}
    get 'iiif_filepath', defaults: {format: 'json'}
    get 'nested_items', to: "nested_items#index"
    get 'refresh_preview'
    get 'view'
    get 'viewtext', defaults: { format: 'json' }
  end
  collection do
    post "create_from_remote", defaults: {format: 'json'}
    post "create_from_url"
    post "remote_content_length", defaults: {format: 'json'}
  end
end