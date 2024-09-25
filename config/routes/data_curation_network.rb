resources :data_curation_network, only: [:index] do
  collection do
    get 'accounts'
    get 'login'
    get 'register'
    get 'my_account'
    get 'datasets'
    get 'after_registration'
    get 'accounts/add', to: 'data_curation_network#add_account'
    get 'accounts/:id/edit', to: 'data_curation_network#edit_account'
  end
end