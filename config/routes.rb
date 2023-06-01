Rails.application.routes.draw do
  root 'pages#index'
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  get '/say', to: 'pages#say'
  post '/say', to: 'pages#create'
  # Defines the root path route ("/")
  # root "articles#index"
end
