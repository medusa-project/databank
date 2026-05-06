require 'rails_helper'

RSpec.describe ExtractorTasksController, type: :controller do
  fixtures :users

  let(:user) { users(:researcher1) }
  let(:datafile) { create(:datafile, web_id: 'extract-web-id') }
  let(:extractor_task) { create(:extractor_task, web_id: datafile.web_id) }

  before do
    sign_in user
    allow(controller).to receive(:authorize!).and_return(true)
  end

  describe 'GET #index' do
    it 'returns a success response' do
      extractor_task

      get :index

      expect(response).to be_successful
      expect(assigns(:extractor_tasks)).to include(extractor_task)
    end
  end

  describe 'GET #show' do
    it 'assigns the extractor task and related datafile' do
      get :show, params: { id: extractor_task.to_param }

      expect(response).to be_successful
      expect(assigns(:extractor_task)).to eq(extractor_task)
      expect(assigns(:datafile)).to eq(datafile)
    end
  end

  describe 'GET #new' do
    it 'assigns a new extractor task' do
      get :new

      expect(response).to be_successful
      expect(assigns(:extractor_task)).to be_a_new(ExtractorTask)
    end
  end

  describe 'GET #edit' do
    it 'assigns the extractor task and related datafile' do
      get :edit, params: { id: extractor_task.to_param }

      expect(response).to be_successful
      expect(assigns(:extractor_task)).to eq(extractor_task)
      expect(assigns(:datafile)).to eq(datafile)
    end
  end

  describe 'POST #create' do
    it 'creates an extractor task from nested extractor_task params' do
      expect {
        post :create, params: { extractor_task: { web_id: datafile.web_id } }
      }.to change(ExtractorTask, :count).by(1)

      expect(response).to redirect_to(ExtractorTask.last)
      expect(flash[:notice]).to eq('Extractor task was successfully created.')
    end

    it 'returns unprocessable content for invalid json params' do
      post :create, params: { extractor_task: { web_id: '' } }, format: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.content_type).to include('application/json')
    end
  end

  describe 'PATCH #update' do
    let!(:other_datafile) { create(:datafile, web_id: 'updated-web-id') }

    it 'updates the extractor task from nested extractor_task params' do
      patch :update, params: { id: extractor_task.to_param, extractor_task: { web_id: other_datafile.web_id } }

      expect(response).to redirect_to(extractor_task)
      expect(flash[:notice]).to eq('Extractor task was successfully updated.')
      expect(extractor_task.reload.web_id).to eq(other_datafile.web_id)
    end

    it 'returns unprocessable content for invalid json params' do
      patch :update, params: { id: extractor_task.to_param, extractor_task: { web_id: '' } }, format: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.content_type).to include('application/json')
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys the extractor task and redirects' do
      extractor_task

      expect {
        delete :destroy, params: { id: extractor_task.to_param }
      }.to change(ExtractorTask, :count).by(-1)

      expect(response).to redirect_to(extractor_tasks_url)
      expect(flash[:notice]).to eq('Extractor task was successfully destroyed.')
    end

    it 'returns no content for json' do
      delete :destroy, params: { id: extractor_task.to_param }, format: :json

      expect(response).to have_http_status(:no_content)
    end
  end
end
