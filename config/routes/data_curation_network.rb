resources :data_curation_network, only: [:index] do
  collection do
    get 'accounts'
    get 'login'
    get 'register'
    get 'my_account'
    get 'datasets'
    get 'after_registration'
    get 'account/add', to: 'data_curation_network#add_account'
    get 'accounts/:id/edit', to: 'data_curation_network#edit_account'
    patch 'identity/:id/update', to: 'data_curation_network#update_identity'
  end
end