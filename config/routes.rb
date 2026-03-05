Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :events, only: [:index, :show], param: :event_id
    end
  end

  get "up", to: proc { [200, {}, ["ok"]] }
end
