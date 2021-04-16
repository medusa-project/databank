# config/routes.rb

Rails.application.routes.draw do


  resources :extractor_tasks
  resources :review_requests do
    collection do
      get 'report'
    end
  end
  resources :password_resets, only: [:new, :create, :edit, :update]
  resources :user_abilities
  resources :contributors
  resources :invitees
  get '/databank_tasks/audit', to: 'databank_tasks#audit'
  get '/databank_tasks/pending', to: 'databank_tasks#pending'
  post '/databank_tasks/update_status', to: 'databank_tasks#update_status', defaults: {format: 'json'}
  resources :databank_tasks, only: [:index, :show]
  resources :ingest_responses
  #mount API::Base => '/api'

  resources :nested_items

  get '/researcher_spotlights', to: 'featured_researchers#index'

  resources :featured_researchers do
    member do
      get 'preview'
    end
  end

  get "/illinois_experts/example", to: "illinois_experts#example", defaults: {format: "xml"}
  get "/illinois_experts/persons", to: "illinois_experts#persons", defaults: {format: "xml"}

  get '/data_curation_network', to: 'data_curation_network#index'
  get '/data_curation_network/accounts', to: 'data_curation_network#accounts'
  get '/data_curation_network/login', to: 'data_curation_network#login'
  get '/data_curation_network/register', to: 'data_curation_network#register'
  get '/data_curation_network/my_account', to: 'data_curation_network#my_account'
  get '/data_curation_network/datasets', to: 'data_curation_network#datasets'
  get '/data_curation_network/after_registration', to: 'data_curation_network#after_registration'
  get '/data_curation_network/account/add', to: 'data_curation_network#add_account'
  get '/data_curation_network/accounts/:id/edit', to: 'data_curation_network#edit_account'
  patch '/data_curation_network/identity/:id/update', to: 'data_curation_network#update_identity'

  get '/featured_researchers/:id', to: 'featured_researchers#show'

  get '/datasets/download_citation_report', to: 'datasets#download_citation_report'

  get '/datasets/:dataset_id/datafiles/add', to: 'datafiles#add'

  get '/datasets/:id/recordtext', to: 'datasets#recordtext'

  get "/datasets/pre_deposit", to: "datasets#pre_deposit"

  get "/on_failed_registration", to: "welcome#on_failed_registration"

  resources :account_activations, only: [:edit]
  resources :related_materials
  resources :funders
  resources :definitions
  resources :medusa_ingests
  post "/medusa_ingests/remove_draft_if_in_medusa", to: "medusa_ingests#remove_draft_if_in_medusa"
  resources :datafiles
  resources :identities do
    collection do
      get 'register'
      get 'login'
    end
  end
  resources :datasets do

    member do
      post 'permissions', to: 'datasets#update_permissions'
      get 'confirm_review', to: 'datasets#confirm_review'
      match 'send_publication_notice', to: 'datasets#send_publication_notice', via: [:get, :post]
    end

    resources :datafiles do
      member do
        get 'upload', to: 'datafiles#upload'
        patch 'upload', to: 'datafiles#do_upload'
        get 'resume_upload', to: 'datafiles#resume_upload'
        patch 'update_status', to: 'datafiles#update_status'
        get 'reset_upload', to: 'datafiles#reset_upload'
        get 'preview', to: 'datafiles#preview'
        get 'view', to: 'datafiles#view'
        get 'filepath', to: 'datafiles#filepath', defaults: {format: 'json'}
        get 'bucket_and_key', to: 'datafiles#bucket_and_key', defaults: {format: 'json'}
        get 'viewtext', to: 'datafiles#peek_text', defaults: {format: 'json'}
        get 'iiif_filepath', to: 'datafiles#iiif_filepath', defaults: {format: 'json'}
        get 'refresh_preview', to: 'datafiles#refresh_preview'
      end
    end
    resources :creators
    resources :funders
    resources :related_materials
    resources :notes
  end
  resources :creators

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  root 'welcome#index'

  get '/', to: 'welcome#index'

  post '/welcome/update_read_only_message', to: 'welcome#update_read_only_message'

  get '/check_token', to: 'welcome#check_token'

  get '/restoration_events', to: 'restoration_events#index'

  get '/audits', to: 'admin#audits'

  get '/policies', to: 'policies#index', :as => :policies
  get '/help', to: 'help#index', :as => :help
  get '/welcome/deposit_login_modal', to: 'welcome#deposit_login_modal'
  get '/datasets/:id/download_endNote_XML', to: 'datasets#download_endNote_XML'
  get '/datasets/:id/download_BibTeX', to: 'datasets#download_BibTeX'
  get '/datasets/:id/download_RIS', to: 'datasets#download_RIS'
  get '/datasets/:id/download_plaintext_citation', to: 'datasets#download_plaintext_citation'
  get '/datasets/:id/download_plaintext_citation', to: 'datasets#download_plaintext_citation'
  get '/datasets/:id/download_box_file/:box_file_id', to: 'datasets#download_box_file'
  post '/datasets/:id/send_to_medusa', to: 'datasets#send_to_medusa', defaults: {format: 'json'}

  post 'api/dataset/:dataset_key/upload', to: 'api_dataset#upload', defaults: {format: 'json'}
  post 'api/dataset/:dataset_key/datafile', to: 'api_dataset#datafile', defaults: {format: 'json'}

  # deposit
  get '/datasets/:id/publish', to: 'datasets#publish'

  # reserve doi
  get '/datasets/:id/reserve_doi', to: 'datasets#reserve_doi', defaults: {format: 'json'}

  # open in Globus
  get '/datasets/:id/open_in_globus', to: 'datasets#open_in_globus'

  # tombstone
  get '/datasets/:id/tombstone', to: 'datasets#tombstone'

  # nuke
  get '/datasets/:id/nuke', to: 'datasets#nuke'

  # import from Globus
  get '/datasets/:id/import_from_globus', to: 'datasets#import_from_globus', defaults: {format: 'json'}

  # review agreement
  get '/review_deposit_agreement', to: 'datasets#review_deposit_agreement'
  get '/datasets/:id/review_deposit_agreement', to: 'datasets#review_deposit_agreement'

  # controller method protected by cancan
  get '/datasets/:id/get_new_token', to: 'datasets#get_new_token', defaults: {format: 'json'}

  get '/datasets/:id/get_current_token', to: 'datasets#get_current_token', defaults: {format: 'json'}

  #add pre-publication review record
  get '/datasets/:id/add_review_request', to: 'dataset#add_review_request'

  # authentication routes
  match '/auth/:provider/callback', to: 'sessions#create', via: [:get, :post]
  match '/login', to: 'sessions#new', as: :login, via: [:get, :post]
  match '/logout', to: 'sessions#destroy', as: :logout, via: [:get, :post]

  match '/auth/failure', to: 'sessions#unauthorized', as: :unauthorized, via: [:get, :post]

  # route binary downloads
  get "/datafiles/:id/download", to: "datafiles#download"

  # route binary downloads from curators
  get "/datafiles/:id/download_no_record", to: "datafiles#download_no_record"

  # refresh preview
  get '/datafiles/:id/refresh_preview', to: "datafiles#refresh_preview"

  # direct view
  get '/datafiles/:id/view', to: "datafiles#view"

  # filepath
  get '/datafiles/:id/filepath', to: "datafiles#filepath", defaults: {format: 'json'}

  # viewtext
  get '/datafiles/:id/viewtext', to: 'datafiles#peek_text', defaults: {format: 'json'}

  # iiif_filepath
  get '/datafiles/:id/iiif_filepath', to: "datafiles#iiif_filepath", defaults: {format: 'json'}

  # create from box file select widget
  post "/datafiles/create_from_url", to: 'datafiles#create_from_url'

  # cancel box upload
  get "/datasets/:id/datafiles/:web_id/cancel_box_upload", to: 'datasets#cancel_box_upload', defaults: {format: 'json'}

  # get citation text
  get "/datasets/:id/citation_text", to: 'datasets#citation_text', defaults: {format: 'json'}

  #determine remote content length, if possible
  post "/datafiles/remote_content_length", to: 'datafiles#remote_content_length', defaults: {format: 'json'}

  #create from url
  post "/datafiles/create_from_remote", to: 'datafiles#create_from_url_unknown_size', defaults: {format: 'json'}

  #get publish confirm message
  get "/datasets/:id/confirmation_message", to: 'datasets#confirmation_message', defaults: {format: 'json'}

  #patch to validate before updating a published dataset
  match "/datasets/:id/validate_change2published", to: 'datasets#validate_change2published', via: [:get, :post, :patch], defaults: {format: 'json'}

  post "/creators/update_row_order", to: 'creators#update_row_order'
  post "/creators/create_for_form", to: 'creators#create_for_form', defaults: {format: 'json'}

  post "/help/help_mail", to: 'help#help_mail', as: :help_mail

  post "/role_switch", to: 'sessions#role_switch'

  get "/datasets/:id/download_link", to: 'datasets#download_link', defaults: {format: 'json'}

  get "/datasets/:id/serialization", to: 'datasets#serialization', defaults: {format: 'json'}

  get "/datasets/:id/changelog", to: 'changelogs#edit'

  get "/metrics/dataset_downloads", to: 'metrics#dataset_downloads', defaults: {format: 'json'}

  get "/metrics/file_downloads", to: 'metrics#file_downloads', defaults: {format: 'json'}

  get "/metrics/datafiles_simple_list", to: "metrics#datafiles_simple_list"

  get "/metrics/datasets_csv", to: "metrics#datasets_csv"

  get "/metrics/funders_csv", to: "metrics#funders_csv"

  get "/metrics/datafiles_csv", to: "metrics#datafiles_csv"

  get "/metrics/related_materials_csv", to: "metrics#related_materials_csv"

  get "/metrics/archived_content_csv", to: "metrics#archived_content_csv"

  get "/metrics", to: 'metrics#index'

  get "/metrics/refresh_dataset_downloads"
  get "/metrics/refresh_datafile_downloads"
  get "/metrics/refresh_datafiles_csv"
  get "/metrics/refresh_container_csv"

  get "/datasets/:id/download_metrics", to: 'datasets#download_metrics', defaults: {format: 'json'}

  get "/datasets/:id/request_review", to: 'datasets#request_review', defaults: {format: 'html'}

  get "/sitemap.xml", to: 'sitemaps#index', defaults: {format: 'xml'}

  get "/robots.:format", to: "welcome#robots"

  # catch unknown routes, but ignore datatables and progress-job routes, which are generated by engines.
  match "/*a" => "errors#error404", :constraints => lambda { |req| req.path !~ /progress-job/ && req.path !~ /datatables/ }, via: [:get, :post, :patch, :delete]

end