require 'rails_helper'

RSpec.describe SessionsController, type: :controller do
  describe 'GET #new' do
    it 'returns success in test/development environments without redirecting' do
      get :new

      expect(response).to be_successful
    end

    it 'stores referer and redirects to shibboleth login outside test/development' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      request.env['HTTP_REFERER'] = '/datasets/abc123'
      expected_target = "https://#{Databank::Application.shibboleth_host}/auth/shibboleth/callback"

      get :new

      expect(session[:login_return_referer]).to eq('/datasets/abc123')
      expect(response).to redirect_to("/Shibboleth.sso/Login?target=#{expected_target}")
    end
  end

  describe 'POST #create' do
    it 'redirects to unauthorized when provider is missing or unsupported' do
      request.env['omniauth.auth'] = { uid: 'person@illinois.edu' }.with_indifferent_access

      post :create, params: { provider: 'unknown' }

      expect(response).to redirect_to(root_url)
      expect(flash[:notice]).to eq('The supplied credentials could not be authenciated.')
    end

    it 'redirects to unauthorized for developer provider outside test/development' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      request.env['omniauth.auth'] = {
        provider: 'developer',
        uid: 'developer@illinois.edu',
        info: { email: 'developer@illinois.edu', name: 'Developer User', role: Databank::UserRole::DEPOSITOR }
      }.with_indifferent_access

      post :create, params: { provider: 'developer' }

      expect(response).to redirect_to(root_url)
      expect(flash[:notice]).to eq('The supplied credentials could not be authenciated.')
    end

    it 'sets session user and redirects to return URL for eligible users' do
      request.env['omniauth.auth'] = {
        provider: 'shibboleth',
        uid: 'person@illinois.edu',
        info: { email: 'person@illinois.edu', name: 'Person', role: Databank::UserRole::DEPOSITOR }
      }.with_indifferent_access
      user = create(:user, role: Databank::UserRole::DEPOSITOR)
      allow(User).to receive(:from_omniauth).and_return(user)
      session[:login_return_uri] = '/datasets/MYDATA-1234567'
      session[:login_return_referer] = '/datasets/fallback'

      post :create, params: { provider: 'shibboleth' }

      expect(session[:user_id]).to eq(user.id)
      expect(response).to redirect_to('/datasets/MYDATA-1234567')
    end

    it 'redirects to root with notice for no_deposit users' do
      request.env['omniauth.auth'] = {
        provider: 'shibboleth',
        uid: 'person@illinois.edu',
        info: { email: 'person@illinois.edu', name: 'Person', role: Databank::UserRole::NO_DEPOSIT }
      }.with_indifferent_access
      user = create(:user, role: Databank::UserRole::NO_DEPOSIT)
      allow(User).to receive(:from_omniauth).and_return(user)

      post :create, params: { provider: 'shibboleth' }

      expect(response).to redirect_to(root_url)
      expect(flash[:notice]).to include('ACCOUNT NOT ELIGABLE TO DEPOSIT DATA.')
    end

    it 'redirects to root when omniauth user is not persisted' do
      request.env['omniauth.auth'] = {
        provider: 'shibboleth',
        uid: 'person@illinois.edu',
        info: { email: 'person@illinois.edu', name: 'Person', role: Databank::UserRole::DEPOSITOR }
      }.with_indifferent_access
      allow(User).to receive(:from_omniauth).and_return(nil)

      post :create, params: { provider: 'shibboleth' }

      expect(response).to redirect_to(root_url)
      expect(session[:user_id]).to be_nil
    end
  end

  describe 'GET #destroy' do
    it 'clears user session and redirects to root' do
      session[:user_id] = 123

      get :destroy

      expect(session[:user_id]).to be_nil
      expect(response).to redirect_to(root_url)
    end
  end

  describe 'GET #unauthorized' do
    it 'redirects to root with authentication notice' do
      get :unauthorized

      expect(response).to redirect_to(root_url)
      expect(flash[:notice]).to eq('The supplied credentials could not be authenciated.')
    end
  end

  describe 'POST #role_switch' do
    let(:user) { create(:user, role: Databank::UserRole::GUEST) }

    before do
      allow(controller).to receive(:current_user).and_return(user)
    end

    it 'switches to depositor role and redirects with success notice' do
      post :role_switch, params: { role: 'depositor' }

      expect(user.reload.role).to eq(Databank::UserRole::DEPOSITOR)
      expect(response).to redirect_to(root_url)
      expect(flash[:notice]).to eq('Successfully switched role to depositor.')
    end

    it 'switches to no_deposit role and uses descriptive notice text' do
      post :role_switch, params: { role: 'no_deposit' }

      expect(user.reload.role).to eq(Databank::UserRole::NO_DEPOSIT)
      expect(response).to redirect_to(root_url)
      expect(flash[:notice]).to include('undergrad, or other authenticated but not authorized agent')
    end

    it 'rejects unknown role values' do
      original_role = user.role

      post :role_switch, params: { role: 'admin' }

      expect(user.reload.role).to eq(original_role)
      expect(response).to redirect_to(root_url)
      expect(flash[:notice]).to eq('Unable to switch roles.')
    end
  end
end
