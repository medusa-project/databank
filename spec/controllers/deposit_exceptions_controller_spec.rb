require 'rails_helper'

RSpec.describe DepositExceptionsController, type: :controller do
  let(:valid_attributes) do
    {
      user_provider: 'shibboleth',
      user_uid: 'person@illinois.edu',
      resource_type: 'Dataset',
      resource_id: nil,
      ability: 'create'
    }
  end

  let(:user_ability) { create(:user_ability, :deposit_exception, user_provider: 'shibboleth', user_uid: 'person@illinois.edu') }

  describe 'GET #index' do
    it 'returns success and assigns deposit exception abilities only' do
      matching = create(:user_ability, :deposit_exception)
      create(:user_ability, :curator)

      get :index

      expect(response).to be_successful
      expect(assigns(:user_abilities)).to include(matching)
      expect(assigns(:user_abilities)).not_to include(UserAbility.where(resource_type: 'Databank').first)
    end
  end

  describe 'GET #show' do
    it 'returns success and assigns requested ability and user' do
      create(:user, provider: user_ability.user_provider, uid: user_ability.user_uid)

      get :show, params: { id: user_ability.id }

      expect(response).to be_successful
      expect(assigns(:user_ability)).to eq(user_ability)
      expect(assigns(:user)).not_to be_nil
    end
  end

  describe 'GET #new' do
    it 'returns success and assigns a new user_ability' do
      get :new

      expect(response).to be_successful
      expect(assigns(:user_ability)).to be_a_new(UserAbility)
    end
  end

  describe 'GET #edit' do
    it 'returns success' do
      get :edit, params: { id: user_ability.id }

      expect(response).to be_successful
    end
  end

  describe 'POST #create' do
    it 'creates a user_ability and redirects for html' do
      expect {
        post :create, params: { user_ability: valid_attributes }
      }.to change(UserAbility, :count).by(1)

      expect(response).to redirect_to('/deposit_exceptions')
      expect(flash[:notice]).to include('successfully created')
    end

    it 'returns created json for valid params' do
      post :create, params: { user_ability: valid_attributes }, format: :json

      expect(response).to have_http_status(:created)
      expect(response.content_type).to include('application/json')
    end

    it 'returns unprocessable content for invalid json params' do
      post :create, params: { user_ability: valid_attributes.merge(user_uid: nil) }, format: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.content_type).to include('application/json')
    end
  end

  describe 'PATCH #update' do
    it 'updates and redirects for html' do
      patch :update, params: { id: user_ability.id, user_ability: { user_uid: 'updated@illinois.edu' } }

      expect(response).to redirect_to('/deposit_exceptions')
      expect(user_ability.reload.user_uid).to eq('updated@illinois.edu')
    end

    it 'returns ok json for valid params' do
      patch :update, params: { id: user_ability.id, user_ability: { user_uid: 'updated@illinois.edu' } }, format: :json

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')
      expect(user_ability.reload.user_uid).to eq('updated@illinois.edu')
    end

    it 'returns unprocessable content for invalid json params' do
      patch :update, params: { id: user_ability.id, user_ability: { user_uid: nil } }, format: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.content_type).to include('application/json')
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys and redirects for html' do
      user_ability

      expect {
        delete :destroy, params: { id: user_ability.id }
      }.to change(UserAbility, :count).by(-1)

      expect(response).to redirect_to('/deposit_exceptions')
    end

    it 'returns no content for json' do
      delete :destroy, params: { id: user_ability.id }, format: :json

      expect(response).to have_http_status(:no_content)
    end
  end
end
