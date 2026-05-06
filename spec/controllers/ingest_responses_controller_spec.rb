# frozen_string_literal: true
# spec/controllers/ingest_responses_controller_spec.rb

require 'rails_helper'

RSpec.describe IngestResponsesController, type: :controller do
  let(:valid_attributes) do
    {
      as_text: 'Response text',
      status: '200 OK',
      response_time: Time.current,
      staging_key: 'staging/key/123',
      medusa_key: 'medusa/key/456',
      uuid: SecureRandom.uuid
    }
  end

  let(:ingest_response) { create(:ingest_response) }

  before do
    # Allow all actions - ingest responses are managed by system
    allow_any_instance_of(Ability).to receive(:can?).and_return(true)
  end

  describe 'GET #index' do
    it 'returns a success response' do
      get :index
      expect(response).to be_successful
    end

    it 'renders the index template' do
      get :index
      expect(response).to render_template(:index)
    end

    it 'assigns all ingest_responses' do
      response1 = create(:ingest_response)
      response2 = create(:ingest_response)
      get :index
      expect(assigns(:ingest_responses)).to match_array([response1, response2])
    end
  end

  describe 'GET #show' do
    it 'returns a success response' do
      get :show, params: { id: ingest_response.to_param }
      expect(response).to be_successful
    end

    it 'renders the show template' do
      get :show, params: { id: ingest_response.to_param }
      expect(response).to render_template(:show)
    end

    it 'assigns the requested ingest_response' do
      get :show, params: { id: ingest_response.to_param }
      expect(assigns(:ingest_response)).to eq(ingest_response)
    end
  end

  describe 'GET #new' do
    it 'returns a success response' do
      get :new
      expect(response).to be_successful
    end

    it 'assigns a new ingest_response' do
      get :new
      expect(assigns(:ingest_response)).to be_a_new(IngestResponse)
    end
  end

  describe 'GET #edit' do
    it 'returns a success response' do
      get :edit, params: { id: ingest_response.to_param }
      expect(response).to be_successful
    end

    it 'assigns the requested ingest_response' do
      get :edit, params: { id: ingest_response.to_param }
      expect(assigns(:ingest_response)).to eq(ingest_response)
    end
  end

  describe 'POST #create' do
    context 'with valid parameters' do
      it 'creates a new IngestResponse' do
        expect do
          post :create, params: { ingest_response: valid_attributes }
        end.to change(IngestResponse, :count).by(1)
      end

      it 'redirects to the created ingest_response' do
        post :create, params: { ingest_response: valid_attributes }
        expect(response).to redirect_to(IngestResponse.last)
      end
    end
  end

  describe 'PATCH/PUT #update' do
    let(:new_attributes) do
      {
        status: 'updated status',
        staging_key: 'updated/key'
      }
    end

    context 'with valid parameters' do
      it 'updates the requested ingest_response' do
        patch :update, params: { id: ingest_response.to_param, ingest_response: new_attributes }
        ingest_response.reload
        expect(ingest_response.status).to eq('updated status')
        expect(ingest_response.staging_key).to eq('updated/key')
      end

      it 'redirects to the ingest_response' do
        patch :update, params: { id: ingest_response.to_param, ingest_response: new_attributes }
        expect(response).to redirect_to(ingest_response)
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys the requested ingest_response' do
      ingest_response_to_delete = create(:ingest_response)
      expect do
        delete :destroy, params: { id: ingest_response_to_delete.to_param }
      end.to change(IngestResponse, :count).by(-1)
    end

    it 'redirects to the ingest_responses list' do
      delete :destroy, params: { id: ingest_response.to_param }
      expect(response).to redirect_to(ingest_responses_url)
    end
  end

  describe 'Strong parameters' do
    it 'permits all expected attributes' do
      params = { ingest_response: valid_attributes }
      post :create, params: params
      response_record = IngestResponse.last
      expect(response_record.status).to eq(valid_attributes[:status])
      expect(response_record.staging_key).to eq(valid_attributes[:staging_key])
      expect(response_record.medusa_key).to eq(valid_attributes[:medusa_key])
      expect(response_record.uuid).to eq(valid_attributes[:uuid])
    end
  end
end
