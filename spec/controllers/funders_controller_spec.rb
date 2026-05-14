require 'rails_helper'

RSpec.describe FundersController, type: :controller do
  let(:dataset) { create(:dataset) }
  let(:funder) { create(:funder, dataset: dataset) }
  let(:valid_attributes) do
    {
      name: 'National Science Foundation',
      identifier: '10.13039/100000001',
      identifier_scheme: 'Crossref Funder ID',
      grant: 'NSF-12345',
      dataset_id: dataset.id
    }
  end

  describe 'GET #index' do
    it 'returns success and assigns funders' do
      funder

      get :index

      expect(response).to be_successful
      expect(assigns(:funders)).to include(funder)
    end

    it 'returns json successfully' do
      funder

      get :index, format: :json

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')
    end
  end

  describe 'GET #show' do
    it 'returns success and assigns funder' do
      get :show, params: { id: funder.id }

      expect(response).to be_successful
      expect(assigns(:funder)).to eq(funder)
    end

    it 'returns json successfully' do
      get :show, params: { id: funder.id }, format: :json

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')
    end
  end

  describe 'GET #new' do
    it 'returns success with new funder' do
      get :new

      expect(response).to be_successful
      expect(assigns(:funder)).to be_a_new(Funder)
    end
  end

  describe 'GET #edit' do
    it 'returns success' do
      get :edit, params: { id: funder.id }

      expect(response).to be_successful
    end
  end

  describe 'POST #create' do
    it 'creates a funder and redirects for html' do
      expect {
        post :create, params: { funder: valid_attributes }
      }.to change(Funder, :count).by(1)

      expect(response).to redirect_to(Funder.last)
    end

    it 'returns created json for valid params' do
      post :create, params: { funder: valid_attributes }, format: :json

      expect(response).to have_http_status(:created)
      expect(response.content_type).to include('application/json')
    end

    it 'returns unprocessable content for invalid json params' do
      post :create, params: { funder: valid_attributes.merge(dataset_id: nil) }, format: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.content_type).to include('application/json')
    end
  end

  describe 'PATCH #update' do
    it 'updates funder and redirects for html' do
      patch :update, params: { id: funder.id, funder: { grant: 'NSF-99999' } }

      expect(response).to redirect_to(funder)
      expect(funder.reload.grant).to eq('NSF-99999')
    end

    it 'returns ok json for valid params' do
      patch :update, params: { id: funder.id, funder: { grant: 'NSF-77777' } }, format: :json

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')
      expect(funder.reload.grant).to eq('NSF-77777')
    end

    it 'returns unprocessable content for invalid json params' do
      patch :update, params: { id: funder.id, funder: { dataset_id: nil } }, format: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.content_type).to include('application/json')
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys funder and redirects for html' do
      funder

      expect {
        delete :destroy, params: { id: funder.id }
      }.to change(Funder, :count).by(-1)

      expect(response).to redirect_to(funders_url)
    end

    it 'returns no content for json' do
      delete :destroy, params: { id: funder.id }, format: :json

      expect(response).to have_http_status(:no_content)
    end
  end
end
