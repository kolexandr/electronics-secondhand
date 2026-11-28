Rails.application.routes.draw do
  resource :registration, only: %i[new create]
  resource :session, only: %i[new create destroy]
  resources :passwords, param: :token, only: %i[new create edit update]
  resources :listings do
    get :mine, on: :collection
  end
  root "listings#index"
  get "up" => "rails/health#show", as: :rails_health_check
end
