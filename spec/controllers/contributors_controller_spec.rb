require 'rails_helper'

RSpec.describe ContributorsController, type: :controller do
  let(:dataset) { create(:dataset) }
  let(:contributor) { create(:contributor, dataset: dataset) }

  let(:valid_attributes) do
    {
      dataset_id: dataset.id,
      given_name: 'Alex',
      family_name: 'Smith',
      type_of: Databank::CreatorType::PERSON,
      email: 'alex.smith@example.org',
      row_position: 1,
      identifier_scheme: 'ORCID'
    }
  end

  describe 'GET #index' do
    it 'returns success and assigns contributors' do
      contributor

      get :index

      expect(response).to be_successful
      expect(assigns(:contributors)).to include(contributor)
    end

    it 'returns json successfully' do
      contributor

      get :index, format: :json

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')
    end
  end

  describe 'GET #show' do
    it 'returns success and assigns contributor' do
      get :show, params: { id: contributor.id }

      expect(response).to be_successful
      expect(assigns(:contributor)).to eq(contributor)
    end

    it 'returns json successfully' do
      get :show, params: { id: contributor.id }, format: :json

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')
    end
  end

  describe 'GET #new' do
    it 'returns success with new contributor' do
      get :new

      expect(response).to be_successful
      expect(assigns(:contributor)).to be_a_new(Contributor)
    end
  end

  describe 'GET #edit' do
    it 'returns success' do
      get :edit, params: { id: contributor.id }

      expect(response).to be_successful
    end
  end

  describe 'POST #create' do
    it 'creates contributor and redirects for html' do
      expect {
        post :create, params: { contributor: valid_attributes }
      }.to change(Contributor, :count).by(1)

      expect(response).to redirect_to(Contributor.last)
    end

    it 'returns created json for valid params' do
      post :create, params: { contributor: valid_attributes }, format: :json

      expect(response).to have_http_status(:created)
      expect(response.content_type).to include('application/json')
    end

    it 'returns unprocessable content for invalid json params' do
      post :create, params: { contributor: valid_attributes.merge(dataset_id: nil) }, format: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.content_type).to include('application/json')
    end
  end

  describe 'PATCH #update' do
    it 'updates contributor and redirects for html' do
      patch :update, params: { id: contributor.id, contributor: { family_name: 'Updated' } }

      expect(response).to redirect_to(contributor)
      expect(contributor.reload.family_name).to eq('Updated')
    end

    it 'returns ok json for valid params' do
      patch :update, params: { id: contributor.id, contributor: { family_name: 'UpdatedJson' } }, format: :json

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')
      expect(contributor.reload.family_name).to eq('UpdatedJson')
    end

    it 'returns unprocessable content for invalid json params' do
      patch :update, params: { id: contributor.id, contributor: { dataset_id: nil } }, format: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.content_type).to include('application/json')
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys contributor and redirects for html' do
      target = create(:contributor, dataset: dataset)

      expect {
        delete :destroy, params: { id: target.id }
      }.to change(Contributor, :count).by(-1)

      expect(response).to redirect_to(contributors_url)
    end

    it 'returns no content for json' do
      delete :destroy, params: { id: contributor.id }, format: :json

      expect(response).to have_http_status(:no_content)
    end
  end
end
