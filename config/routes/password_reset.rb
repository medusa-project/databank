get '/password_resets/new', to: 'password_resets#new'
post '/password_resets', to: 'password_resets#create'
get '/password_resets/:id/edit', to: 'password_resets#edit'
patch '/password_resets/:id', to: 'password_resets#update'