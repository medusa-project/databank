require 'rails_helper'

RSpec.describe MedusaIngestsController, type: :controller do
  let(:medusa_ingest) { create(:medusa_ingest, staging_key: 'draft/object.key') }
  let!(:matching_response) { create(:ingest_response, staging_key: 'draft/object.key') }
  let!(:other_response) { create(:ingest_response, staging_key: 'other/object.key') }
  let(:valid_attributes) do
    {
      idb_class: 'datafile',
      idb_identifier: 'web-123',
      staging_path: 'staging/path',
      request_status: 'pending',
      medusa_path: 'medusa/path',
      medusa_uuid: SecureRandom.uuid,
      response_time: Time.current,
      error_text: 'none',
      staging_key: 'draft/created.key',
      target_key: 'medusa/created.key',
      medusa_dataset_dir: 'dataset-created'
    }
  end

  describe 'GET #index' do
    it 'returns a success response with medusa ingests ordered by created_at desc' do
      older = create(:medusa_ingest, created_at: 1.day.ago)
      newer = create(:medusa_ingest, created_at: Time.current)

      get :index

      expect(response).to be_successful
      expect(assigns(:medusa_ingests).first).to eq(newer)
      expect(assigns(:medusa_ingests)).to include(older)
    end
  end

  describe 'GET #show' do
    it 'assigns matching ingest responses by staging_key' do
      get :show, params: { id: medusa_ingest.to_param }

      expect(response).to be_successful
      expect(assigns(:ingest_responses)).to match_array([matching_response])
    end
  end

  describe 'GET #new' do
    it 'assigns a new medusa ingest' do
      get :new

      expect(response).to be_successful
      expect(assigns(:medusa_ingest)).to be_a_new(MedusaIngest)
    end
  end

  describe 'GET #edit' do
    it 'assigns the requested medusa ingest' do
      get :edit, params: { id: medusa_ingest.to_param }

      expect(response).to be_successful
      expect(assigns(:medusa_ingest)).to eq(medusa_ingest)
    end
  end

  describe 'POST #create' do
    it 'creates a medusa ingest with the form-backed attributes' do
      expect {
        post :create, params: { medusa_ingest: valid_attributes }
      }.to change(MedusaIngest, :count).by(1)

      created = MedusaIngest.last
      expect(response).to redirect_to(created)
      expect(created.staging_key).to eq('draft/created.key')
      expect(created.target_key).to eq('medusa/created.key')
      expect(created.medusa_dataset_dir).to eq('dataset-created')
    end

    it 'returns created json for valid params' do
      post :create, params: { medusa_ingest: valid_attributes }, format: :json

      expect(response).to have_http_status(:created)
      expect(response.content_type).to include('application/json')
    end

    it 'returns unprocessable content when save fails for json' do
      errors = double(as_json: { base: ['invalid'] })
      allow_any_instance_of(MedusaIngest).to receive(:save).and_return(false)
      allow_any_instance_of(MedusaIngest).to receive(:errors).and_return(errors)

      post :create, params: { medusa_ingest: valid_attributes }, format: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.content_type).to include('application/json')
    end
  end

  describe 'PATCH #update' do
    it 'updates the permitted form-backed attributes' do
      patch :update, params: {
        id: medusa_ingest.to_param,
        medusa_ingest: { staging_key: 'draft/updated.key', target_key: 'medusa/updated.key', medusa_dataset_dir: 'dataset-updated' }
      }

      expect(response).to redirect_to(medusa_ingest)
      expect(medusa_ingest.reload.staging_key).to eq('draft/updated.key')
      expect(medusa_ingest.target_key).to eq('medusa/updated.key')
      expect(medusa_ingest.medusa_dataset_dir).to eq('dataset-updated')
    end

    it 'returns ok json for valid params' do
      patch :update, params: { id: medusa_ingest.to_param, medusa_ingest: { request_status: 'complete' } }, format: :json

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')
      expect(medusa_ingest.reload.request_status).to eq('complete')
    end

    it 'returns unprocessable content when update fails for json' do
      errors = double(as_json: { base: ['invalid'] })
      allow(MedusaIngest).to receive(:find).with(medusa_ingest.to_param).and_return(medusa_ingest)
      allow(medusa_ingest).to receive(:update).and_return(false)
      allow(medusa_ingest).to receive(:errors).and_return(errors)

      patch :update, params: { id: medusa_ingest.to_param, medusa_ingest: { request_status: 'failed' } }, format: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.content_type).to include('application/json')
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys the medusa ingest and redirects for html' do
      medusa_ingest

      expect {
        delete :destroy, params: { id: medusa_ingest.to_param }
      }.to change(MedusaIngest, :count).by(-1)

      expect(response).to redirect_to(medusa_ingests_url)
      expect(flash[:notice]).to eq('Medusa ingest was successfully destroyed.')
    end

    it 'returns no content for json' do
      delete :destroy, params: { id: medusa_ingest.to_param }, format: :json

      expect(response).to have_http_status(:no_content)
    end
  end
end
