Rails.application.routes.draw do
  resource :registration, only: %i[new create]
  resource :session, only: %i[new create destroy]
  resources :passwords, param: :token, only: %i[new create edit update]
  resources :listings do
    get :mine, on: :collection
    resources :reservations, only: :create
  end
  resources :reservations, only: %i[index show] do
    post :cancel, on: :member
    post :checkout, on: :member
  end
  resources :orders, only: :show
  root "listings#index"
  get "up" => "rails/health#show", as: :rails_health_check
end
