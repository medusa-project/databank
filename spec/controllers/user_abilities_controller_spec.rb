require 'rails_helper'

RSpec.describe UserAbilitiesController, type: :controller do
  let(:admin) { create(:user, :admin) }

  before do
    sign_in admin
  end

  describe 'GET #index' do
    it 'returns success' do
      get :index
      expect(response).to be_successful
    end
  end

  describe 'GET #new' do
    it 'returns success' do
      get :new
      expect(response).to be_successful
    end
  end

  describe 'POST #create' do
    it 'redirects to deposit exceptions for a deposit exception ability' do
      post :create, params: {
        user_ability: {
          user_provider: 'shibboleth',
          user_uid: 'person@illinois.edu',
          resource_type: 'Dataset',
          resource_id: nil,
          ability: 'create'
        }
      }

      expect(response).to redirect_to('/deposit_exceptions')
    end

    it 'redirects to curators for a curator ability' do
      post :create, params: {
        user_ability: {
          user_provider: 'shibboleth',
          user_uid: 'person@illinois.edu',
          resource_type: 'Databank',
          resource_id: nil,
          ability: 'manage'
        }
      }

      expect(response).to redirect_to('/curators')
    end

    it 'redirects to the created user ability for a regular ability' do
      post :create, params: {
        user_ability: {
          user_provider: 'shibboleth',
          user_uid: 'person@illinois.edu',
          resource_type: 'Dataset',
          resource_id: 1,
          ability: 'read'
        }
      }

      expect(response).to redirect_to(user_ability_path(UserAbility.last))
    end

    it 'renders new when save fails' do
      allow_any_instance_of(UserAbility).to receive(:save).and_return(false)

      post :create, params: {
        user_ability: {
          user_provider: 'shibboleth',
          user_uid: 'person@illinois.edu',
          resource_type: 'Dataset',
          resource_id: 1,
          ability: 'read'
        }
      }

      expect(response).to render_template(:new)
    end
  end

  describe 'PUT #update' do
    let!(:user_ability) do
      UserAbility.create!(
        user_provider: 'shibboleth',
        user_uid: 'person@illinois.edu',
        resource_type: 'Dataset',
        resource_id: 1,
        ability: 'read'
      )
    end

    it 'redirects to deposit exceptions when updated ability is a deposit exception' do
      put :update, params: {
        id: user_ability.id,
        user_ability: {
          resource_type: 'Dataset',
          resource_id: nil,
          ability: 'create'
        }
      }

      expect(response).to redirect_to('/deposit_exceptions')
    end

    it 'renders edit when update fails' do
      allow_any_instance_of(UserAbility).to receive(:update).and_return(false)

      put :update, params: {
        id: user_ability.id,
        user_ability: {
          resource_type: 'Dataset',
          resource_id: 2,
          ability: 'read'
        }
      }

      expect(response).to render_template(:edit)
    end
  end

  describe 'DELETE #destroy' do
    it 'redirects to deposit exceptions when deleting a deposit exception' do
      ua = UserAbility.create!(
        user_provider: 'shibboleth',
        user_uid: 'person@illinois.edu',
        resource_type: 'Dataset',
        resource_id: nil,
        ability: 'create'
      )

      delete :destroy, params: { id: ua.id }

      expect(response).to redirect_to('/deposit_exceptions')
    end

    it 'redirects to user abilities list for a regular ability' do
      ua = UserAbility.create!(
        user_provider: 'shibboleth',
        user_uid: 'person@illinois.edu',
        resource_type: 'Dataset',
        resource_id: 1,
        ability: 'read'
      )

      delete :destroy, params: { id: ua.id }

      expect(response).to redirect_to(user_abilities_url)
    end
  end
end