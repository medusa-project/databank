resources :curator_reports do
  member do
    get 'download'
  end
  collection do
    post 'request_file_audit'
  end
end
