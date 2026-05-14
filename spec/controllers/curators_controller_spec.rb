# frozen_string_literal: true
# spec/controllers/curators_controller_spec.rb

require 'rails_helper'

RSpec.describe CuratorsController, type: :controller do
  let(:valid_attributes) do
    {
      user_provider: 'developer',
      user_uid: 'test@illinois.edu',
      resource_type: 'Databank',
      ability: 'manage'
    }
  end

  let(:user_ability) { create(:user_ability) }

  before do
    allow(IDB_CONFIG).to receive(:[]).and_call_original
    allow(IDB_CONFIG).to receive(:[]).with(:admin).and_return(netids: 'admin1, admin2')
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

    it 'assigns @config_admin_uids from configuration' do
      get :index
      expect(assigns(:config_admin_uids)).to eq(['admin1@illinois.edu', 'admin2@illinois.edu'])
    end

    it 'assigns @curators from User model' do
      user = create(:user, provider: 'developer', uid: 'curator1')
      create(:user_ability, :curator, user_provider: 'developer', user_uid: 'curator1')
      get :index
      curators = assigns(:curators)
      expect(curators.map(&:uid)).to include('curator1')
    end

    it 'assigns @curator_ability_user_not_found for orphaned abilities' do
      orphaned_ability = create(:user_ability, :curator, user_uid: 'orphaned@illinois.edu')
      get :index
      expect(assigns(:curator_ability_user_not_found)).to include(orphaned_ability)
    end
  end

  describe 'GET #show' do
    it 'returns a success response' do
      user_ability = create(:user_ability)
      get :show, params: { id: user_ability.to_param }
      expect(response).to be_successful
    end

    it 'renders the show template' do
      user_ability = create(:user_ability)
      get :show, params: { id: user_ability.to_param }
      expect(response).to render_template(:show)
    end

    it 'assigns the requested user_ability' do
      user_ability = create(:user_ability)
      get :show, params: { id: user_ability.to_param }
      expect(assigns(:user_ability)).to eq(user_ability)
    end

    it 'finds the associated user when it exists' do
      user = create(:user, provider: 'developer')
      user_ability = create(:user_ability, user_provider: 'developer', user_uid: user.uid)
      get :show, params: { id: user_ability.to_param }
      expect(assigns(:user)).to eq(user)
    end

    it 'sets @user to nil when user not found' do
      user_ability = create(:user_ability)
      get :show, params: { id: user_ability.to_param }
      expect(assigns(:user)).to be_nil
    end
  end

  describe 'GET #new' do
    it 'returns a success response' do
      get :new
      expect(response).to be_successful
    end

    it 'renders the new template' do
      get :new
      expect(response).to render_template(:new)
    end

    it 'assigns a new user_ability' do
      get :new
      expect(assigns(:user_ability)).to be_a_new(UserAbility)
    end
  end

  describe 'GET #edit' do
    it 'returns a success response' do
      user_ability = create(:user_ability)
      get :edit, params: { id: user_ability.to_param }
      expect(response).to be_successful
    end

    it 'renders the edit template' do
      user_ability = create(:user_ability)
      get :edit, params: { id: user_ability.to_param }
      expect(response).to render_template(:edit)
    end

    it 'assigns the requested user_ability' do
      user_ability = create(:user_ability)
      get :edit, params: { id: user_ability.to_param }
      expect(assigns(:user_ability)).to eq(user_ability)
    end
  end

  describe 'POST #create' do
    context 'with valid parameters' do
      it 'creates a new UserAbility' do
        expect do
          post :create, params: { user_ability: valid_attributes }
        end.to change(UserAbility, :count).by(1)
      end

      it 'redirects to the curators index' do
        post :create, params: { user_ability: valid_attributes }
        expect(response).to redirect_to('/curators')
      end

      it 'sets a success flash message' do
        post :create, params: { user_ability: valid_attributes }
        expect(flash[:notice]).to include('successfully added')
      end
    end

    context 'with invalid parameters' do
      it 'does not create when required fields are blank' do
        expect do
          post :create, params: { user_ability: { user_provider: nil, user_uid: nil } }
        end.not_to change(UserAbility, :count)
      end

      it 'renders the new template on validation failure' do
        post :create, params: { user_ability: { user_provider: nil, user_uid: nil } }
        expect(response).to render_template(:new)
      end
    end
  end

  describe 'PATCH/PUT #update' do
    let(:user_ability) { create(:user_ability) }
    let(:new_attributes) do
      {
        user_uid: 'updated@illinois.edu'
      }
    end

    context 'with valid parameters' do
      it 'updates the requested user_ability' do
        patch :update, params: { id: user_ability.to_param, user_ability: new_attributes }
        user_ability.reload
        expect(user_ability.user_uid).to eq('updated@illinois.edu')
      end

      it 'redirects to the curators index' do
        patch :update, params: { id: user_ability.to_param, user_ability: new_attributes }
        expect(response).to redirect_to('/curators')
      end

      it 'sets a success flash message' do
        patch :update, params: { id: user_ability.to_param, user_ability: new_attributes }
        expect(flash[:notice]).to include('successfully updated')
      end
    end

    context 'with invalid parameters' do
      it 'does not update when setting required fields to nil' do
        original_uid = user_ability.user_uid
        patch :update, params: { id: user_ability.to_param, user_ability: { user_uid: nil } }
        user_ability.reload
        expect(user_ability.user_uid).to eq(original_uid)
      end

      it 'renders the edit template on validation failure' do
        patch :update, params: { id: user_ability.to_param, user_ability: { user_uid: nil } }
        expect(response).to render_template(:edit)
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys the requested user_ability' do
      user_ability = create(:user_ability)
      expect do
        delete :destroy, params: { id: user_ability.to_param }
      end.to change(UserAbility, :count).by(-1)
    end

    it 'redirects to the curators index' do
      user_ability = create(:user_ability)
      delete :destroy, params: { id: user_ability.to_param }
      expect(response).to redirect_to('/curators')
    end

    it 'sets a success flash message' do
      user_ability = create(:user_ability)
      delete :destroy, params: { id: user_ability.to_param }
      expect(flash[:notice]).to include('successfully removed')
    end
  end

  describe 'Strong parameters' do
    it 'permits all expected attributes' do
      params = { user_ability: valid_attributes }
      post :create, params: params
      ability = UserAbility.last
      expect(ability.user_provider).to eq(valid_attributes[:user_provider])
      expect(ability.user_uid).to eq(valid_attributes[:user_uid])
      expect(ability.resource_type).to eq(valid_attributes[:resource_type])
      expect(ability.ability).to eq(valid_attributes[:ability])
    end

    it 'does not permit unexpected attributes' do
      params = { user_ability: valid_attributes.merge(created_at: 1.day.ago) }
      post :create, params: params
      ability = UserAbility.last
      expect(ability.created_at).not_to eq(1.day.ago)
    end
  end
end
