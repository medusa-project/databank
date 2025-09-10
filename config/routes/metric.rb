get "/metric", to: 'metrics#index'
resources :metrics do
  collection do
    get 'archived_content_csv'
    get 'datafiles_csv'
    get 'datafiles_simple_list'
    get 'dataset_downloads', defaults: {format: 'json'}
    get 'downloads'
    get 'file_downloads', defaults: {format: 'json'}
    get 'funders_csv'
    get 'refresh_dataset_downloads'
    get 'refresh_datafile_downloads'
    get 'refresh_datafiles_csv'
    get 'refresh_container_csv'
    get 'related_materials_csv'
    get 'refresh_datasets_tsv'
    get 'refresh_funders_csv'
    get 'refresh_related_materials_csv'
    get 'refresh_container_contents_csv'
  end
end