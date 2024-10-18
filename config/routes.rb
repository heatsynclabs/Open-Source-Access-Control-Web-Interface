Dooraccess::Application.routes.draw do
  match 'ipns/import' => 'ipns#import', :as => :import_ipn, via: [:get, :post]
  resources :ipns
  match 'ipns/:id/link' => 'ipns#link', :as => :link_ipn, via: [:get, :post]
  match 'ipns/:id/validate' => 'ipns#validate', :as => :validate_ipn, via: [:get, :post]

  resources :paypal_csvs
  match 'paypal_csvs/:id/link' => 'paypal_csvs#link', :as => :link_paypal_csv, via: [:get, :post]

  resources :payments
  resources :resources
  resources :resource_categories, except: :show

  match 'statistics' => 'statistics#index', :as => :statistics, via: [:get, :post]
  match 'statistics/mac_log' => 'statistics#mac_log', :as => :mac_statistics, via: [:get, :post]
  match 'statistics/door_log' => 'statistics#door_log', :as => :door_statistics, via: [:get, :post]

  resources :user_certifications
  resources :certifications
  resources :contracts

  match 'contracts/find_for_user/:user_id' => 'contracts#find_for_user', as: 'find_for_user', via: [:get, :post]

  devise_for :users, :skip => :registrations
  devise_scope :user do
    resource :registration,
      :only => [:new, :create, :edit, :update],
      :path => 'users',
      :path_names => { :new => 'sign_up' },
      :controller => 'registrations',
      :as => :user_registration do
        get :cancel
      end
  end

  match 'user_summary/:id' => 'users#user_summary', via: [:get, :post]
  match 'users/activity' => 'users#activity', via: [:get, :post]
  match 'users/new_member_report' => 'users#new_member_report', via: [:get, :post]
  get 'users/merge' => 'users#merge_view', via: [:get, :post]
  post 'users/merge' => 'users#merge_action', via: [:get, :post]
  match 'users/inactive' => 'users#inactive', via: [:get, :post]

  resources :users do
    get 'email' => 'users#compose_email', :as => "compose_email"
    post 'email' => 'users#send_email'
    resources 'contracts', only: [:index]
  end
  post 'users/create' => 'users#create' # Use POST users/create instead of POST users to avoid devise conflict

  match 'cards/upload_all' => 'cards#upload_all', :as => :upload_all, via: [:get, :post]
  match 'cards/authorize/:id' => 'cards#authorize', :as => :authorize, via: [:get, :post]
  resources :cards
  match 'cards/:id/upload' => 'cards#upload', :as => :upload, via: [:get, :post]

  match 'space_api' => 'space_api#index', :as => :space_api, via: [:get, :post]
  match 'space_api/simple(.format)' => 'space_api#simple', :as => :space_api_simple, via: [:get, :post]
  get 'space_api/alert_if_not/:status' => 'space_api#alert_if_not_status', :as => :space_api_alert_if_not_status
  get 'space_api/access' => 'space_api#access', :as => :space_api_access
  post 'space_api/access' => 'space_api#access_post'

  match 'door_logs' => 'door_logs#index', :as => :door_logs, via: [:get, :post]
  match 'door_logs/download' => 'door_logs#download', :as => :download, via: [:get, :post]
  match 'door_logs/auto_download' => 'door_logs#auto_download', :as => :auto_download, via: [:get, :post]

  match 'macs/scan' => 'macs#scan', via: [:get, :post]
  match 'macs/import' => 'macs#import', via: [:get, :post]
  match 'macs/history' => 'macs#history', via: [:get, :post]
  resources :macs
  resources :mac_logs

  resources :settings, :only => [:index, :edit, :update]

  match 'more_info' => 'home#more_info', via: [:get, :post]
  root :to => "home#index"
end
