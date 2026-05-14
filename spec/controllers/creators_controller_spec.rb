require 'rails_helper'

RSpec.describe CreatorsController, type: :controller do
  let(:dataset) { create(:dataset) }
  let(:creator) do
    create(
      :creator,
      dataset: dataset,
      type_of: Databank::CreatorType::INSTITUTION,
      institution_name: 'University Library',
      is_contact: false
    )
  end

  let(:valid_attributes) do
    {
      dataset_id: dataset.id,
      type_of: Databank::CreatorType::INSTITUTION,
      institution_name: 'Illinois Data Service',
      email: 'editor@illinois.edu',
      is_contact: false
    }
  end

  describe 'GET #index' do
    it 'returns success' do
      creator
      get :index

      expect(response).to be_successful
      expect(assigns(:creators)).to include(creator)
    end

    it 'returns json response for index' do
      creator

      get :index, format: :json

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')
    end
  end

  describe 'GET #show' do
    it 'returns success' do
      get :show, params: { id: creator.id }

      expect(response).to be_successful
    end

    it 'returns json response for show' do
      get :show, params: { id: creator.id }, format: :json

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')
    end
  end

  describe 'GET #new' do
    it 'returns success' do
      get :new

      expect(response).to be_successful
      expect(assigns(:creator)).to be_a_new(Creator)
    end
  end

  describe 'GET #edit' do
    it 'returns success' do
      get :edit, params: { id: creator.id }

      expect(response).to be_successful
    end
  end

  describe 'POST #create' do
    it 'creates a creator with valid params' do
      expect {
        post :create, params: { creator: valid_attributes }
      }.to change(Creator, :count).by(1)

      expect(response).to redirect_to(Creator.last)
    end

    it 'returns unprocessable content for invalid json request' do
      post :create, params: { creator: { dataset_id: dataset.id, type_of: Databank::CreatorType::PERSON } }, format: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH #update' do
    it 'updates creator with valid params' do
      patch :update, params: { id: creator.id, creator: { institution_name: 'Updated Name' } }

      expect(response).to redirect_to(creator)
      expect(creator.reload.institution_name).to eq('Updated Name')
    end

    it 'returns ok for valid json update' do
      patch :update, params: { id: creator.id, creator: { institution_name: 'Updated Name' } }, format: :json

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')
    end

    it 'renders edit for invalid html update' do
      patch :update, params: { id: creator.id, creator: { institution_name: '', given_name: '' } }

      expect(response).to render_template(:edit)
    end

    it 'returns unprocessable content for invalid json update' do
      patch :update, params: { id: creator.id, creator: { institution_name: '', given_name: '' } }, format: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys the creator' do
      creator

      expect {
        delete :destroy, params: { id: creator.id }
      }.to change(Creator, :count).by(-1)
    end

    it 'redirects to creators index for html' do
      delete :destroy, params: { id: creator.id }

      expect(response).to redirect_to(creators_url)
    end

    it 'returns no content for json' do
      delete :destroy, params: { id: creator.id }, format: :json

      expect(response).to have_http_status(:no_content)
    end
  end

  describe 'POST #update_row_order' do
    it 'updates row_position from row_order_position param' do
      creator.update!(row_position: 1)

      post :update_row_order, params: { creator: { creator_id: creator.id, row_order_position: 4 } }

      expect(response).to have_http_status(:ok)
      expect(creator.reload.row_position).to eq(4)
    end

    it 'updates row_position from row_position param' do
      creator.update!(row_position: 1)

      post :update_row_order, params: { creator: { creator_id: creator.id, row_position: 3 } }

      expect(response).to have_http_status(:ok)
      expect(creator.reload.row_position).to eq(3)
    end
  end

  describe 'GET #orcid_search' do
    before do
      allow(controller).to receive(:authorize!).with(:search_orcid, Creator).and_return(true)
    end

    it 'returns ok with orcid search payload' do
      allow(Creator).to receive(:orcid_identifier).and_return({ 'result' => [{ 'orcid-identifier' => '0000-0001-1111-2222' }] })

      get :orcid_search, params: { family_name: 'Doe', given_names: 'Pat' }, format: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to include('result')
    end

    it 'returns no result payload when lookup returns nil' do
      allow(Creator).to receive(:orcid_identifier).and_return(nil)

      get :orcid_search, params: { family_name: 'Doe', given_names: 'Pat' }, format: :json

      expect(response).to be_successful
      expect(JSON.parse(response.body)).to eq('error' => 'no result', 'status' => 'expectation_failed')
    end

    it 'returns error payload when lookup raises' do
      allow(Creator).to receive(:orcid_identifier).and_raise(StandardError, 'orcid unavailable')

      get :orcid_search, params: { family_name: 'Doe', given_names: 'Pat' }, format: :json

      expect(response).to be_successful
      expect(JSON.parse(response.body)).to eq('error' => 'orcid unavailable')
    end
  end

  describe 'GET #orcid_person' do
    before do
      allow(controller).to receive(:authorize!).with(:search_orcid, Creator).and_return(true)
    end

    it 'returns ok with person payload' do
      allow(Creator).to receive(:orcid_person).and_return({ 'name' => 'Pat Doe' })

      get :orcid_person, params: { orcid: '0000-0001-1111-2222' }, format: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq('name' => 'Pat Doe')
    end

    it 'returns error payload when lookup raises' do
      allow(Creator).to receive(:orcid_person).and_raise(StandardError, 'person lookup failed')

      get :orcid_person, params: { orcid: '0000-0001-1111-2222' }, format: :json

      expect(response).to be_successful
      expect(JSON.parse(response.body)).to eq('error' => 'person lookup failed')
    end
  end
end
