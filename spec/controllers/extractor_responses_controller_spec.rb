require 'rails_helper'

RSpec.describe ExtractorResponsesController, type: :controller do
  let(:extractor_task) { create(:extractor_task) }
  let(:extractor_response) { create(:extractor_response, extractor_task: extractor_task) }
  let(:valid_attributes) do
    {
      extractor_task_id: extractor_task.id,
      web_id: 'alpha123',
      status: 'success',
      peek_type: 'text/plain',
      peek_text: 'peek body'
    }
  end
  let(:invalid_attributes) do
    {
      extractor_task_id: nil,
      web_id: 'alpha123',
      status: 'failed',
      peek_type: 'text/plain',
      peek_text: 'peek body'
    }
  end

  describe 'GET #index' do
    it 'returns a success response and assigns all extractor responses' do
      extractor_response

      get :index

      expect(response).to be_successful
      expect(assigns(:extractor_responses)).to include(extractor_response)
    end

    it 'returns json successfully' do
      extractor_response

      get :index, format: :json

      expect(response).to be_successful
      expect(response.content_type).to include('application/json')
    end
  end

  describe 'GET #show' do
    it 'returns a success response and assigns the record' do
      get :show, params: { id: extractor_response.to_param }

      expect(response).to be_successful
      expect(assigns(:extractor_response)).to eq(extractor_response)
    end

    it 'returns json successfully' do
      get :show, params: { id: extractor_response.to_param }, format: :json

      expect(response).to be_successful
      expect(response.content_type).to include('application/json')
    end
  end

  describe 'GET #new' do
    it 'assigns a new extractor response' do
      get :new

      expect(response).to be_successful
      expect(assigns(:extractor_response)).to be_a_new(ExtractorResponse)
    end
  end

  describe 'GET #edit' do
    it 'assigns the requested extractor response' do
      get :edit, params: { id: extractor_response.to_param }

      expect(response).to be_successful
      expect(assigns(:extractor_response)).to eq(extractor_response)
    end
  end

  describe 'POST #create' do
    it 'creates an extractor response and redirects for html' do
      expect {
        post :create, params: { extractor_response: valid_attributes }
      }.to change(ExtractorResponse, :count).by(1)

      expect(response).to redirect_to(ExtractorResponse.last)
      expect(flash[:notice]).to eq('Extractor response was successfully created.')
    end

    it 'returns created json for valid params' do
      post :create, params: { extractor_response: valid_attributes }, format: :json

      expect(response).to have_http_status(:created)
      expect(response.content_type).to include('application/json')
    end

    it 'returns unprocessable content for invalid params in html' do
      expect {
        post :create, params: { extractor_response: invalid_attributes }
      }.not_to change(ExtractorResponse, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response).to render_template(:new)
    end

    it 'returns unprocessable content for invalid params in json' do
      post :create, params: { extractor_response: invalid_attributes }, format: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.content_type).to include('application/json')
    end
  end

  describe 'PATCH #update' do
    it 'updates the extractor response and redirects for html' do
      patch :update, params: { id: extractor_response.to_param, extractor_response: { status: 'failed' } }

      expect(response).to redirect_to(extractor_response)
      expect(flash[:notice]).to eq('Extractor response was successfully updated.')
      expect(extractor_response.reload.status).to eq('failed')
    end

    it 'returns ok json for valid params' do
      patch :update, params: { id: extractor_response.to_param, extractor_response: { status: 'processing' } }, format: :json

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')
      expect(extractor_response.reload.status).to eq('processing')
    end

    it 'returns unprocessable content for invalid html update' do
      patch :update, params: { id: extractor_response.to_param, extractor_response: { extractor_task_id: nil } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response).to render_template(:edit)
    end

    it 'returns unprocessable content for invalid json update' do
      patch :update, params: { id: extractor_response.to_param, extractor_response: { extractor_task_id: nil } }, format: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.content_type).to include('application/json')
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys the response and redirects for html' do
      extractor_response

      expect {
        delete :destroy, params: { id: extractor_response.to_param }
      }.to change(ExtractorResponse, :count).by(-1)

      expect(response).to redirect_to(extractor_responses_url)
      expect(flash[:notice]).to eq('Extractor response was successfully destroyed.')
    end

    it 'returns no content for json' do
      delete :destroy, params: { id: extractor_response.to_param }, format: :json

      expect(response).to have_http_status(:no_content)
    end
  end
end
