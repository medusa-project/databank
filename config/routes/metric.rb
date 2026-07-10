get "/metric", to: 'metrics#index'
get "/admin_metrics", to: 'metrics#admin_metrics', as: :admin_metrics
resources :metrics do
  collection do
    get 'archived_content_csv'
    get 'datafiles_csv'
    get 'datafiles_simple_list'
    get 'dataset_downloads_csv'
    get 'datafile_downloads_csv'
    get 'funders_csv'
    get 'refresh_dataset_downloads_csv'
    get 'refresh_datafile_downloads_csv'
    get 'refresh_datafiles_csv'
    get 'refresh_container_csv'
    get 'related_materials_csv'
    get 'refresh_datasets_tsv'
    get 'refresh_funders_csv'
    get 'refresh_related_materials_csv'
    get 'refresh_container_contents_csv'
  end
end