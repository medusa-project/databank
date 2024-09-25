get '/guides', to: 'guide/sections#guides'
get '/help', to: 'guide/sections#guides'
namespace :guide do
  resources :subitems do
    collection do
      post 'reorder'
    end
  end
  resources :items do
    collection do
      post 'reorder'
    end
  end
  resources :sections do
    collection do
      post 'reorder'
    end
  end
end