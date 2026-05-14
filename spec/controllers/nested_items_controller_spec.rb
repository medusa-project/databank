require 'rails_helper'

RSpec.describe NestedItemsController, type: :controller do
  let(:datafile) { create(:datafile, web_id: 'nested-web-id') }
  let(:other_datafile) { create(:datafile, web_id: 'other-web-id') }
  let(:valid_attributes) do
    {
      datafile_id: datafile.id,
      parent_id: nil,
      item_name: 'nested-file.txt',
      media_type: 'text/plain',
      size: 128
    }
  end
  let(:nested_item) { create(:nested_item, datafile: datafile) }

  describe 'GET #index' do
    it 'returns all nested items when no id filter is provided' do
      nested_item
      other_item = create(:nested_item, datafile: other_datafile)

      get :index

      expect(response).to be_successful
      expect(assigns(:nested_items)).to match_array([nested_item, other_item])
    end

    it 'filters nested items by datafile web_id when id is provided' do
      nested_item
      create(:nested_item, datafile: other_datafile)

      get :index, params: { id: datafile.web_id }

      expect(response).to be_successful
      expect(assigns(:nested_items)).to match_array([nested_item])
    end

    it 'leaves all nested items assigned when the datafile filter is not found' do
      nested_item
      other_item = create(:nested_item, datafile: other_datafile)

      get :index, params: { id: 'missing-web-id' }

      expect(response).to be_successful
      expect(assigns(:nested_items)).to match_array([nested_item, other_item])
    end
  end

  describe 'GET #show' do
    it 'returns a success response' do
      get :show, params: { id: nested_item.to_param }

      expect(response).to be_successful
      expect(assigns(:nested_item)).to eq(nested_item)
    end
  end

  describe 'GET #new' do
    it 'assigns a new nested item' do
      get :new

      expect(response).to be_successful
      expect(assigns(:nested_item)).to be_a_new(NestedItem)
    end
  end

  describe 'GET #edit' do
    it 'assigns the requested nested item' do
      get :edit, params: { id: nested_item.to_param }

      expect(response).to be_successful
      expect(assigns(:nested_item)).to eq(nested_item)
    end
  end

  describe 'POST #create' do
    it 'creates a nested item and redirects for html requests' do
      expect {
        post :create, params: { nested_item: valid_attributes }
      }.to change(NestedItem, :count).by(1)

      expect(response).to redirect_to(NestedItem.last)
      expect(flash[:notice]).to eq('Nested item was successfully created.')
    end

    it 'returns created json for json requests' do
      post :create, params: { nested_item: valid_attributes }, format: :json

      expect(response).to have_http_status(:created)
      expect(response.content_type).to include('application/json')
    end
  end

  describe 'PATCH #update' do
    it 'updates the nested item and redirects for html requests' do
      patch :update, params: { id: nested_item.to_param, nested_item: { item_name: 'renamed.txt' } }

      expect(response).to redirect_to(nested_item)
      expect(flash[:notice]).to eq('Nested item was successfully updated.')
      expect(nested_item.reload.item_name).to eq('renamed.txt')
    end

    it 'returns ok json for json requests' do
      patch :update, params: { id: nested_item.to_param, nested_item: { item_name: 'renamed.json.txt' } }, format: :json

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')
      expect(nested_item.reload.item_name).to eq('renamed.json.txt')
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys the nested item and redirects for html requests' do
      nested_item

      expect {
        delete :destroy, params: { id: nested_item.to_param }
      }.to change(NestedItem, :count).by(-1)

      expect(response).to redirect_to(nested_item_url)
      expect(flash[:notice]).to eq('Nested item was successfully destroyed.')
    end

    it 'returns no content for json requests' do
      delete :destroy, params: { id: nested_item.to_param }, format: :json

      expect(response).to have_http_status(:no_content)
    end
  end
end
