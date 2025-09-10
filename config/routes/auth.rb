resources :account_activations, only: [:edit]
resources :curators
resources :deposit_exceptions
match '/auth/failure', to: 'sessions#unauthorized', as: :unauthorized, via: [:get, :post]
match '/auth/:provider/callback', to: 'sessions#create', via: [:get, :post]
get '/check_token', to: 'welcome#check_token'
match '/login', to: 'sessions#new', as: :login, via: [:get, :post]
match '/logout', to: 'sessions#destroy', as: :logout, via: [:get, :post]
get "/on_failed_registration", to: "welcome#on_failed_registration"
match '/auth/:provider', to: 'sessions#new', via: [:get, :post]
resources :password_resets, only: [:new, :create, :edit, :update]
resources :user_abilities
get '/welcome/deposit_login_modal', to: 'welcome#deposit_login_modal'