require 'rails_helper'

RSpec.describe CuratorsController, type: :controller do
  fixtures :users, :datasets

  let(:valid_attributes) {
    {
      user_provider: 'developer',
      user_uid: 'curator2@mailinator.com',
      resource_type: 'Databank',
      resource_id: nil,
      ability: 'manage'
    }
  }

  let(:invalid_attributes) {
    {
      user_provider: nil,
      user_uid: nil,
      resource_type: nil,
      resource_id: nil,
      ability: nil
    }
  }

  let(:user) { users(:cur) }
  let(:user_ability) { UserAbility.create!(valid_attributes) }

  before do
    sign_in user
  end

  describe "GET #index" do
    it "returns a success response" do
      get :index
      expect(response).to be_successful
      expect(assigns(:user_abilities)).to include(hash_including('user_provider' => 'developer', 'user_uid' => 'curator2@mailinator.com', 'name' => 'curator2'))
    end
  end

  describe "GET #show" do
    it "returns a success response" do
      get :show, params: { id: user_ability.to_param }
      expect(response).to be_successful
    end
  end

  describe "GET #new" do
    it "returns a success response" do
      get :new
      expect(response).to be_successful
    end
  end

  describe "GET #edit" do
    it "returns a success response" do
      get :edit, params: { id: user_ability.to_param }
      expect(response).to be_successful
    end
  end

  describe "POST #create" do
    context "with valid params" do
      it "creates a new UserAbility" do
        expect {
          post :create, params: { user_ability: valid_attributes }
        }.to change(UserAbility, :count).by(1)
      end

      it "redirects to the curators list" do
        post :create, params: { user_ability: valid_attributes }
        expect(response).to redirect_to("/curators")
      end
    end

    context "with invalid params" do
      it "returns a success response (i.e., to display the 'new' template)" do
        post :create, params: { user_ability: invalid_attributes }
        expect(response).to be_successful
      end
    end
  end

  describe "PUT #update" do
    context "with valid params" do
      let(:new_attributes) {
        {
          ability: 'edit'
        }
      }

      it "updates the requested user_ability" do
        put :update, params: { id: user_ability.to_param, user_ability: new_attributes }
        user_ability.reload
        expect(user_ability.ability).to eq('edit')
      end

      it "redirects to the curators list" do
        put :update, params: { id: user_ability.to_param, user_ability: valid_attributes }
        expect(response).to redirect_to("/curators")
      end
    end

    context "with invalid params" do
      it "returns a success response (i.e., to display the 'edit' template)" do
        put :update, params: { id: user_ability.to_param, user_ability: invalid_attributes }
        expect(response).to be_successful
      end
    end
  end

  describe "DELETE #destroy" do
    it "destroys the requested user_ability" do
      user_ability = UserAbility.create!(valid_attributes)
      expect {
        delete :destroy, params: { id: user_ability.to_param }
      }.to change(UserAbility, :count).by(-1)
    end

    it "redirects to the curators list" do
      delete :destroy, params: { id: user_ability.to_param }
      expect(response).to redirect_to("/curators")
    end
  end
end