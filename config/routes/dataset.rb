resources :datasets do
  member do
    get 'add_review_request'
    get "citation_text", defaults: {format: 'json'}
    get "confirmation_message", defaults: {format: 'json'}
    get 'confirm_review'
    post 'copy_version_files'
    get 'download_BibTeX'
    get 'download_box_file/:box_file_id', to: 'datasets#download_box_file'
    get 'download_endNote_XML'
    get "download_link", defaults: {format: 'json'}
    get "download_metrics", defaults: {format: 'json'}
    get 'download_plaintext_citation'
    get 'download_RIS'
    get 'draft_to_version'
    get 'get_current_token', defaults: {format: 'json'}
    get 'get_new_token', defaults: {format: 'json'}
    get 'import_from_globus', defaults: {format: 'json'}
    get 'medusa_details'
    get 'nuke'
    get 'open_in_globus'
    get 'open_in_granite'
    get 'permanently_suppress_files'
    get 'permanently_suppress_metadata'
    get 'permissions'
    get 'publish'
    get 'record_text'
    delete 'remove_sharing_link'
    get "request_review", defaults: {format: 'html'}
    get 'reserve_doi', defaults: {format: 'json'}
    get 'review_deposit_agreement'
    get 'review_requests'
    post 'send_publication_notice'
    post 'send_to_medusa', defaults: { format: 'json' }
    get "serialization", defaults: {format: 'json'}
    get 'share'
    get 'suppress_changelog'
    get 'suppress_review'
    post 'suppression_action'
    get 'suppression_controls'
    get 'temporarily_suppress_files'
    get 'temporarily_suppress_metadata'
    get 'tombstone'
    post 'update_permissions'
    get 'unsuppress_changelog'
    get 'unsuppress_review'
    get 'unsuppress'
    match "validate_change2published", via: [:get, :post, :patch], defaults: {format: 'json'}
    get 'version', to: 'datasets#pre_version'
    get 'version_acknowledge'
    match 'version_confirm', via: [:get, :post, :patch]
    get 'version_controls'
    get 'version_request'
    get 'version_to_draft'
  end
  collection do
    get 'download_citation_report'
    get 'pre_deposit'
    get 'review_deposit_agreement'
  end
  resources :creators
  resources :datafiles do
    member do
      get 'bucket_and_key', to: 'datafiles#bucket_and_key', defaults: { format: 'json' }
      get 'iiif_filepath', to: 'datafiles#iiif_filepath', defaults: { format: 'json' }
      get 'filepath', to: 'datafiles#filepath', defaults: { format: 'json' }
      get 'upload', to: 'datafiles#upload'
      patch 'upload', to: 'datafiles#do_upload'
      get 'resume_upload', to: 'datafiles#resume_upload'
      patch 'update_status', to: 'datafiles#update_status'
      get 'reset_upload'
      get 'preview'
      get 'view'
      get 'viewtext', defaults: { format: 'json' }
      get 'refresh_preview'
    end
    collection do
      get 'add', to: 'datafiles#add'
    end
  end
  resources :funders
  resources :notes
  resources :related_materials
end
