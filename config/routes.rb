Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resources :registrations, except: [ :index, :show, :destroy ]
  mount MissionControl::Jobs::Engine, at: "/jobs"
  resources :contacts, only: [ :new, :create, :show ]
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "pages#index"

  # Service pages
  get "global-corporate-strategy", to: "pages#global_corporate_strategy", as: :global_corporate_strategy
  get "intellectual-property", to: "pages#intellectual_property", as: :intellectual_property
  get "finance-and-investments", to: "pages#finance_and_investments", as: :finance_and_investments
  get "legal-and-compliance", to: "pages#legal_and_compliance", as: :legal_and_compliance
  get "operational-excellence", to: "pages#operational_excellence", as: :operational_excellence
  get "risk-esg-and-governance", to: "pages#risk_esg_and_governance", as: :risk_esg_and_governance
  get "services", to: "pages#services"
  get "about", to: "pages#about"

  # Principle pages
  get "single-north-star", to: "pages#single_north_star", as: :single_north_star
  get "live-impact-thrive", to: "pages#live_impact_thrive", as: :live_impact_thrive
  get "impact-beyond-us", to: "pages#impact_beyond_us", as: :impact_beyond_us
end
