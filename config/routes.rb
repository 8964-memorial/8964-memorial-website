Rails.application.routes.draw do
  root 'pages#index'
  
  # Memorial message routes
  get '/say', to: 'pages#say'
  post '/say', to: 'pages#create'
  
  # Health check for monitoring
  get '/health', to: proc { [200, {}, ['OK']] }
end
