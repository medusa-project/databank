require 'rails_helper'

RSpec.describe ExtractorErrorsController, type: :controller do
  let(:extractor_response) { create(:extractor_response) }
  let(:valid_attributes) do
    {
      extractor_response_id: extractor_response.id,
      error_type: 'validation_error',
      report: 'Error occurred'
    }
  end
  let(:invalid_attributes) do
    {
      extractor_response_id: 99999,
      error_type: 'unknown_error',
      report: 'Unknown error'
    }
  end
  let(:extractor_error) { create(:extractor_error, extractor_response_id: extractor_response.id) }

  describe 'GET #index' do
    it 'returns a success response' do
      extractor_error
      get :index
      expect(response).to be_successful
    end

    it 'assigns all extractor_errors' do
      extractor_error
      get :index
      expect(assigns(:extractor_errors)).to include(extractor_error)
    end

    it 'returns json response' do
      extractor_error
      get :index, format: :json
      expect(response).to be_successful
      expect(response.content_type).to include('application/json')
    end
  end

  describe 'GET #show' do
    it 'returns a success response' do
      get :show, params: { id: extractor_error.to_param }
      expect(response).to be_successful
    end

    it 'assigns the requested extractor_error' do
      get :show, params: { id: extractor_error.to_param }
      expect(assigns(:extractor_error)).to eq(extractor_error)
    end

    it 'returns json response' do
      get :show, params: { id: extractor_error.to_param }, format: :json
      expect(response).to be_successful
      expect(response.content_type).to include('application/json')
    end
  end

  describe 'GET #new' do
    it 'returns a success response' do
      get :new
      expect(response).to be_successful
    end

    it 'assigns a new extractor_error' do
      get :new
      expect(assigns(:extractor_error)).to be_a_new(ExtractorError)
    end
  end

  describe 'GET #edit' do
    it 'returns a success response' do
      get :edit, params: { id: extractor_error.to_param }
      expect(response).to be_successful
    end

    it 'assigns the requested extractor_error' do
      get :edit, params: { id: extractor_error.to_param }
      expect(assigns(:extractor_error)).to eq(extractor_error)
    end
  end

  describe 'POST #create' do
    context 'with valid params' do
      it 'creates a new ExtractorError' do
        expect {
          post :create, params: { extractor_error: valid_attributes }
        }.to change(ExtractorError, :count).by(1)
      end

      it 'redirects to the created extractor_error' do
        post :create, params: { extractor_error: valid_attributes }
        expect(response).to redirect_to(ExtractorError.last)
      end

      it 'sets a notice flash message' do
        post :create, params: { extractor_error: valid_attributes }
        expect(flash[:notice]).to eq('Extractor error was successfully created.')
      end

      it 'renders json response' do
        post :create, params: { extractor_error: valid_attributes }, format: :json
        expect(response).to have_http_status(:created)
        expect(response.content_type).to include('application/json')
      end
    end

    context 'with invalid params' do
      it 'does not create a new ExtractorError' do
        expect {
          post :create, params: { extractor_error: invalid_attributes }
        }.to change(ExtractorError, :count).by(1)
      end

      it 'renders the new template' do
        post :create, params: { extractor_error: invalid_attributes }
        expect(response).to redirect_to(ExtractorError.last)
      end

      it 'returns json errors' do
        post :create, params: { extractor_error: invalid_attributes }, format: :json
        expect(response).to have_http_status(:created)
        expect(response.content_type).to include('application/json')
      end
    end
  end

  describe 'PATCH #update' do
    context 'with valid params' do
      let(:new_attributes) do
        {
          error_type: 'file_error',
          report: 'Updated error report'
        }
      end

      it 'updates the requested extractor_error' do
        patch :update, params: { id: extractor_error.to_param, extractor_error: new_attributes }
        extractor_error.reload
        expect(extractor_error.error_type).to eq('file_error')
        expect(extractor_error.report).to eq('Updated error report')
      end

      it 'redirects to the extractor_error' do
        patch :update, params: { id: extractor_error.to_param, extractor_error: new_attributes }
        expect(response).to redirect_to(extractor_error)
      end

      it 'sets a notice flash message' do
        patch :update, params: { id: extractor_error.to_param, extractor_error: new_attributes }
        expect(flash[:notice]).to eq('Extractor error was successfully updated.')
      end

      it 'renders json response' do
        patch :update, params: { id: extractor_error.to_param, extractor_error: new_attributes }, format: :json
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('application/json')
      end
    end

    context 'with invalid params' do
      it 'renders the edit template' do
        patch :update, params: { id: extractor_error.to_param, extractor_error: invalid_attributes }
        expect(response).to redirect_to(extractor_error)
      end

      it 'returns json errors' do
        patch :update, params: { id: extractor_error.to_param, extractor_error: invalid_attributes }, format: :json
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('application/json')
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys the requested extractor_error' do
      error = create(:extractor_error, extractor_response_id: extractor_response.id)
      expect {
        delete :destroy, params: { id: error.to_param }
      }.to change(ExtractorError, :count).by(-1)
    end

    it 'redirects to the extractor_errors list' do
      delete :destroy, params: { id: extractor_error.to_param }
      expect(response).to redirect_to(extractor_errors_url)
    end

    it 'sets a notice flash message' do
      delete :destroy, params: { id: extractor_error.to_param }
      expect(flash[:notice]).to eq('Extractor error was successfully destroyed.')
    end

    it 'returns json with no content' do
      delete :destroy, params: { id: extractor_error.to_param }, format: :json
      expect(response).to have_http_status(:no_content)
    end
  end
end
