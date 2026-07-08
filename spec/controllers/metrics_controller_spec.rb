require 'rails_helper'
require 'rake'
require 'fileutils'

RSpec.describe MetricsController, type: :controller do
  def metric_output_paths
    METRICS_CONFIG.values.filter_map do |config|
      config[:relative_path] if config.is_a?(Hash) && config[:relative_path].present?
    end
  end

  def metric_artifact_paths
    metric_output_paths + metric_output_paths.map { |path| "#{path}.lock" }
  end

  def snapshot_metric_artifacts
    metric_artifact_paths.to_h do |path|
      [path, File.exist?(path) ? File.binread(path) : nil]
    end
  end

  def restore_metric_artifacts!(snapshots)
    snapshots.each do |path, contents|
      if contents.nil?
        File.delete(path) if File.exist?(path)
      else
        FileUtils.mkdir_p(File.dirname(path))
        File.binwrite(path, contents)
      end
    end
  end

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
    @metric_artifact_snapshots = snapshot_metric_artifacts
    ensure_metrics_static_files!
  end

  after(:all) do
    restore_metric_artifacts!(@metric_artifact_snapshots)
  end

  describe 'GET #index' do
    it 'renders the metrics dashboard page and sets title' do
      get :index

      expect(response).to be_successful
      expect(assigns(:title)).to eq('Metrics')
      expect(response.content_type).to include('text/html')
      expect(response).to render_template(:index)
    end
  end

  describe 'GET #admin_metrics' do
    it 'shows not authorized message when not logged in' do
      allow(controller).to receive(:current_user).and_return(nil)
      allow(controller).to receive(:authorize!).and_raise(CanCan::AccessDenied.new('Not authorized', :manage, :all))

      get :admin_metrics

      expect(response).to redirect_to(IDB_CONFIG[:root_url_text])
      expect(flash[:alert]).to eq('You are not authorized to access the requested resource.')
    end

    it 'shows not authorized message when logged in without access' do
      allow(controller).to receive(:current_user).and_return(double('User', role: 'depositor'))
      allow(controller).to receive(:authorize!).and_raise(CanCan::AccessDenied.new('Not authorized', :manage, :all))

      get :admin_metrics

      expect(response).to redirect_to(IDB_CONFIG[:root_url_text])
      expect(flash[:alert]).to eq('You are not authorized to access the requested resource.')
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
    it 'initiates refresh and redirects to metrics index' do
      job = instance_double(MetricRefreshJob)
      delayed = double('DelayedProxy')
      allow(Metric).to receive(:in_progress?).with(:dataset_downloads_json).and_return(false)
      allow(Metric).to receive(:set_in_progress).with(:dataset_downloads_json)
      allow(MetricRefreshJob).to receive(:new).with(:dataset_downloads_json).and_return(job)
      allow(job).to receive(:delay).and_return(delayed)
      allow(delayed).to receive(:perform)

      get :refresh_dataset_downloads

      expect(response).to redirect_to(metrics_path)
      expect(flash[:notice]).to include('refresh started')
      expect(Metric).to have_received(:set_in_progress).with(:dataset_downloads_json)
      expect(MetricRefreshJob).to have_received(:new).with(:dataset_downloads_json)
    end
  end

  describe 'GET #refresh_datafile_downloads' do
    it 'initiates refresh and redirects to metrics index' do
      job = instance_double(MetricRefreshJob)
      delayed = double('DelayedProxy')
      allow(Metric).to receive(:in_progress?).with(:datafile_downloads_json).and_return(false)
      allow(Metric).to receive(:set_in_progress).with(:datafile_downloads_json)
      allow(MetricRefreshJob).to receive(:new).with(:datafile_downloads_json).and_return(job)
      allow(job).to receive(:delay).and_return(delayed)
      allow(delayed).to receive(:perform)

      get :refresh_datafile_downloads

      expect(response).to redirect_to(metrics_path)
      expect(flash[:notice]).to include('refresh started')
      expect(MetricRefreshJob).to have_received(:new).with(:datafile_downloads_json)
    end
  end

  describe 'GET #refresh_datasets_tsv' do
    it 'initiates refresh and redirects to metrics index' do
      job = instance_double(MetricRefreshJob)
      delayed = double('DelayedProxy')
      allow(Metric).to receive(:in_progress?).with(:datasets_tsv).and_return(false)
      allow(Metric).to receive(:set_in_progress).with(:datasets_tsv)
      allow(MetricRefreshJob).to receive(:new).with(:datasets_tsv).and_return(job)
      allow(job).to receive(:delay).and_return(delayed)
      allow(delayed).to receive(:perform)

      get :refresh_datasets_tsv

      expect(response).to redirect_to(metrics_path)
      expect(flash[:notice]).to include('refresh started')
      expect(MetricRefreshJob).to have_received(:new).with(:datasets_tsv)
    end
  end

  describe 'GET #refresh_datafiles_csv' do
    it 'initiates refresh and redirects to metrics index' do
      job = instance_double(MetricRefreshJob)
      delayed = double('DelayedProxy')
      allow(Metric).to receive(:in_progress?).with(:datafiles_csv).and_return(false)
      allow(Metric).to receive(:set_in_progress).with(:datafiles_csv)
      allow(MetricRefreshJob).to receive(:new).with(:datafiles_csv).and_return(job)
      allow(job).to receive(:delay).and_return(delayed)
      allow(delayed).to receive(:perform)

      get :refresh_datafiles_csv

      expect(response).to redirect_to(metrics_path)
      expect(flash[:notice]).to include('refresh started')
      expect(MetricRefreshJob).to have_received(:new).with(:datafiles_csv)
    end
  end

  describe 'GET #refresh_container_csv' do
    it 'initiates refresh and redirects to metrics index' do
      job = instance_double(MetricRefreshJob)
      delayed = double('DelayedProxy')
      allow(Metric).to receive(:in_progress?).with(:container_contents_csv).and_return(false)
      allow(Metric).to receive(:set_in_progress).with(:container_contents_csv)
      allow(MetricRefreshJob).to receive(:new).with(:container_contents_csv).and_return(job)
      allow(job).to receive(:delay).and_return(delayed)
      allow(delayed).to receive(:perform)

      get :refresh_container_csv

      expect(response).to redirect_to(metrics_path)
      expect(flash[:notice]).to include('refresh started')
      expect(MetricRefreshJob).to have_received(:new).with(:container_contents_csv)
    end
  end

  describe 'GET #refresh_funders_csv' do
    it 'initiates refresh and redirects to metrics index' do
      job = instance_double(MetricRefreshJob)
      delayed = double('DelayedProxy')
      allow(Metric).to receive(:in_progress?).with(:funders_csv).and_return(false)
      allow(Metric).to receive(:set_in_progress).with(:funders_csv)
      allow(MetricRefreshJob).to receive(:new).with(:funders_csv).and_return(job)
      allow(job).to receive(:delay).and_return(delayed)
      allow(delayed).to receive(:perform)

      get :refresh_funders_csv

      expect(response).to redirect_to(metrics_path)
      expect(flash[:notice]).to include('refresh started')
      expect(MetricRefreshJob).to have_received(:new).with(:funders_csv)
    end
  end

  describe 'GET #refresh_related_materials_csv' do
    it 'initiates refresh and redirects to metrics index' do
      job = instance_double(MetricRefreshJob)
      delayed = double('DelayedProxy')
      allow(Metric).to receive(:in_progress?).with(:related_materials_csv).and_return(false)
      allow(Metric).to receive(:set_in_progress).with(:related_materials_csv)
      allow(MetricRefreshJob).to receive(:new).with(:related_materials_csv).and_return(job)
      allow(job).to receive(:delay).and_return(delayed)
      allow(delayed).to receive(:perform)

      get :refresh_related_materials_csv

      expect(response).to redirect_to(metrics_path)
      expect(flash[:notice]).to include('refresh started')
      expect(MetricRefreshJob).to have_received(:new).with(:related_materials_csv)
    end
  end

  describe 'GET #refresh_container_contents_csv' do
    it 'initiates refresh and redirects to metrics index' do
      job = instance_double(MetricRefreshJob)
      delayed = double('DelayedProxy')
      allow(Metric).to receive(:in_progress?).with(:container_contents_csv).and_return(false)
      allow(Metric).to receive(:set_in_progress).with(:container_contents_csv)
      allow(MetricRefreshJob).to receive(:new).with(:container_contents_csv).and_return(job)
      allow(job).to receive(:delay).and_return(delayed)
      allow(delayed).to receive(:perform)

      get :refresh_container_contents_csv

      expect(response).to redirect_to(metrics_path)
      expect(flash[:notice]).to include('refresh started')
      expect(MetricRefreshJob).to have_received(:new).with(:container_contents_csv)
    end
  end
end
