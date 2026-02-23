Rails.application.routes.draw do
  resource :session, only: %i[new create destroy]
  resource :registration, only: %i[new create]
  resources :passwords, only: %i[new create edit update], param: :token
  resource :account, only: %i[edit update]
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "chat_rooms#index"

  resources :chat_rooms, only: %i[index show new create] do
    resources :chat_messages, only: :create
    resource :bot_setting, only: :update, controller: "chat_room_bot_settings"
    resource :bot_reply_session, only: :create, controller: "chat_room_bot_reply_sessions"
  end
end
