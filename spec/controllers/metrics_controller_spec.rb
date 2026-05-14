require 'rails_helper'
require 'rake'

RSpec.describe MetricsController, type: :controller do
  def ensure_metrics_static_files!
    required_paths = [
      Rails.root.join('public/dataset_downloads.json').to_s,
      Rails.root.join('public/datafile_downloads.json').to_s,
      Rails.root.join('public/archive_file_contents.csv').to_s
    ]

    return if required_paths.all? { |path| File.exist?(path) }

    Rails.application.load_tasks unless Rake::Task.task_defined?('metrics:generate_docs')
    Rake::Task['metrics:generate_docs'].reenable
    Rake::Task['metrics:generate_docs'].invoke
  end

  before(:all) do
    ensure_metrics_static_files!
  end

  describe 'GET #index' do
    it 'assigns modified times and title' do
      allow(Metric).to receive(:modified_times).and_return({ dataset_downloads: 'now' })

      get :index

      expect(response).to be_successful
      expect(assigns(:modified_times)).to eq(dataset_downloads: 'now')
      expect(assigns(:title)).to eq('Metrics')
    end
  end

  describe 'GET #dataset_downloads' do
    it 'returns dataset downloads json content' do
      get :dataset_downloads, format: :json

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq('application/json')
    end

    it 'returns not_found when dataset downloads file is missing' do
      path = Rails.root.join('public/dataset_downloads.json').to_s
      allow(File).to receive(:file?).and_call_original
      allow(File).to receive(:file?).with(path).and_return(false)

      get :dataset_downloads, format: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET #file_downloads' do
    it 'returns datafile downloads json content' do
      get :file_downloads, format: :json

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq('application/json')
    end
  end

  describe 'GET #datafiles_simple_list' do
    it 'assigns datafiles for metadata-public datasets' do
      datafile = create(:datafile)
      allow_any_instance_of(Dataset).to receive(:metadata_public?).and_return(true)

      get :datafiles_simple_list

      expect(response).to be_successful
      expect(assigns(:datafiles)).to include(datafile)
    end
  end

  describe 'GET #archived_content_csv' do
    it 'returns archived content csv' do
      get :archived_content_csv

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('text/csv')
    end
  end

  describe 'GET #datafiles_csv' do
    it 'returns datafiles csv content' do
      get :datafiles_csv

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('text/csv')
    end
  end

  describe 'GET #funders_csv' do
    it 'returns funders csv content' do
      get :funders_csv

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('text/csv')
    end
  end

  describe 'GET #related_materials_csv' do
    it 'returns related materials csv content' do
      get :related_materials_csv

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('text/csv')
    end
  end

  describe 'GET #refresh_dataset_downloads' do
    it 'initiates refresh and renders index' do
      allow(Metric).to receive(:write_dataset_downloads_json)

      get :refresh_dataset_downloads

      expect(response).to be_successful
      expect(Metric).to have_received(:write_dataset_downloads_json)
    end
  end

  describe 'GET #refresh_datafile_downloads' do
    it 'initiates refresh and redirects to metrics index' do
      allow(Metric).to receive(:write_datafile_downloads_json)

      get :refresh_datafile_downloads

      expect(response).to redirect_to(metrics_path)
      expect(flash[:notice]).to include('Dataset downloads json refresh initiated')
    end
  end

  describe 'GET #refresh_datasets_tsv' do
    it 'initiates refresh and redirects to metrics index' do
      allow(Metric).to receive(:write_datasets_tsv)

      get :refresh_datasets_tsv

      expect(response).to redirect_to(metrics_path)
      expect(flash[:notice]).to include('Datasets tsv refresh initiated')
    end
  end

  describe 'GET #refresh_datafiles_csv' do
    it 'initiates refresh and redirects to metrics index' do
      allow(Metric).to receive(:write_datafiles_csv)

      get :refresh_datafiles_csv

      expect(response).to redirect_to(metrics_path)
      expect(flash[:notice]).to include('Datafiles csv refresh initiated')
    end
  end

  describe 'GET #refresh_container_csv' do
    it 'initiates refresh and redirects to metrics index' do
      allow(Metric).to receive(:write_container_contents_csv)

      get :refresh_container_csv

      expect(response).to redirect_to(metrics_path)
      expect(flash[:notice]).to include('Container contents csv refresh initiated')
    end
  end

  describe 'GET #refresh_funders_csv' do
    it 'initiates refresh and redirects to metrics index' do
      allow(Metric).to receive(:write_funders_csv)

      get :refresh_funders_csv

      expect(response).to redirect_to(metrics_path)
      expect(flash[:notice]).to include('Funders csv refresh initiated')
    end
  end

  describe 'GET #refresh_related_materials_csv' do
    it 'initiates refresh and redirects to metrics index' do
      allow(Metric).to receive(:write_related_materials_csv)

      get :refresh_related_materials_csv

      expect(response).to redirect_to(metrics_path)
      expect(flash[:notice]).to include('Related materials csv refresh initiated')
    end
  end

  describe 'GET #refresh_container_contents_csv' do
    it 'initiates refresh and redirects to metrics index' do
      allow(Metric).to receive(:write_container_contents_csv)

      get :refresh_container_contents_csv

      expect(response).to redirect_to(metrics_path)
      expect(flash[:notice]).to include('Container contents csv refresh initiated')
    end
  end
end
