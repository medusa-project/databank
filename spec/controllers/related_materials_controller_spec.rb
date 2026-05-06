require 'rails_helper'

RSpec.describe RelatedMaterialsController, type: :controller do
  let(:dataset) { create(:dataset) }
  let(:related_material) { create(:related_material, dataset: dataset) }
  let(:valid_attributes) do
    {
      material_type: 'Article',
      availability: 'public',
      link: 'https://example.org/article',
      uri: 'https://doi.org/10.1000/example',
      uri_type: 'DOI',
      citation: 'Example citation',
      dataset_id: dataset.id,
      feature: false,
      note: ''
    }
  end

  describe 'GET #index' do
    it 'returns success and assigns related materials' do
      related_material

      get :index

      expect(response).to be_successful
      expect(assigns(:related_materials)).to include(related_material)
    end

    it 'returns json successfully' do
      related_material

      get :index, format: :json

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')
    end
  end

  describe 'GET #show' do
    it 'returns success and assigns related material' do
      get :show, params: { id: related_material.id }

      expect(response).to be_successful
      expect(assigns(:related_material)).to eq(related_material)
    end

    it 'returns json successfully' do
      get :show, params: { id: related_material.id }, format: :json

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')
    end
  end

  describe 'GET #new' do
    it 'returns success with new related material' do
      get :new

      expect(response).to be_successful
      expect(assigns(:related_material)).to be_a_new(RelatedMaterial)
    end
  end

  describe 'GET #edit' do
    it 'returns success' do
      get :edit, params: { id: related_material.id }

      expect(response).to be_successful
    end
  end

  describe 'POST #create' do
    it 'creates related material and redirects for html' do
      expect {
        post :create, params: { related_material: valid_attributes }
      }.to change(RelatedMaterial, :count).by(1)

      expect(response).to redirect_to(RelatedMaterial.last)
    end

    it 'returns created json for valid params' do
      post :create, params: { related_material: valid_attributes }, format: :json

      expect(response).to have_http_status(:created)
      expect(response.content_type).to include('application/json')
    end

    it 'returns unprocessable content for invalid json params' do
      post :create, params: { related_material: valid_attributes.merge(dataset_id: nil) }, format: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.content_type).to include('application/json')
    end
  end

  describe 'PATCH #update' do
    it 'updates related material and redirects for html' do
      patch :update, params: { id: related_material.id, related_material: { note: 'updated note' } }

      expect(response).to redirect_to(related_material)
      expect(related_material.reload.note).to eq('updated note')
    end

    it 'returns ok json for valid params' do
      patch :update, params: { id: related_material.id, related_material: { note: 'updated note json' } }, format: :json

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')
      expect(related_material.reload.note).to eq('updated note json')
    end

    it 'returns unprocessable content for invalid json params' do
      patch :update, params: { id: related_material.id, related_material: { dataset_id: nil } }, format: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.content_type).to include('application/json')
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys related material and redirects for html' do
      related_material

      expect {
        delete :destroy, params: { id: related_material.id }
      }.to change(RelatedMaterial, :count).by(-1)

      expect(response).to redirect_to(related_materials_url)
    end

    it 'returns no content for json' do
      delete :destroy, params: { id: related_material.id }, format: :json

      expect(response).to have_http_status(:no_content)
    end
  end
end
