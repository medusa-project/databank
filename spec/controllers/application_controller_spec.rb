require 'rails_helper'

RSpec.describe ApplicationController, type: :controller do
  controller(ApplicationController) do
    def index
      render plain: 'ok'
    end

    def login
      render plain: 'ok'
    end

    def process_error
      error_occurred(request.env['test.exception'])
    end
  end

  before do
    routes.draw do
      get 'index' => 'anonymous#index'
      get 'login' => 'anonymous#login'
      get 'process_error' => 'anonymous#process_error'
    end
  end

  describe '#store_location' do
    it 'stores fullpath for normal GET requests' do
      get :index, params: { section: 'recent' }

      expect(session[:previous_url]).to eq('/index?section=recent')
    end

    it 'stores root URL text for login path' do
      get :login

      expect(session[:previous_url]).to eq(IDB_CONFIG[:root_url_text])
    end

    it 'stores root URL text for xhr requests' do
      get :index, xhr: true

      expect(session[:previous_url]).to eq(IDB_CONFIG[:root_url_text])
    end
  end

  describe '#redirect_path' do
    it 'returns previous_url when present' do
      session[:previous_url] = '/index?page=2'

      expect(controller.redirect_path).to eq('/index?page=2')
    end

    it 'falls back to root URL text when previous_url is absent' do
      session[:previous_url] = nil

      expect(controller.redirect_path).to eq(IDB_CONFIG[:root_url_text])
    end
  end

  describe '#error_occurred' do
    def exception_with_instance_of(klass, message: 'simulated error')
      exception = StandardError.new(message)
      allow(exception).to receive(:instance_of?) { |arg| arg == klass }
      exception
    end

    it 'redirects with bad_request for Solr HTTP errors' do
      session[:previous_url] = '/index?section=errors'
      exception = exception_with_instance_of(RSolr::Error::Http)
      request.env['test.exception'] = exception

      get :process_error

      expect(response).to have_http_status(:bad_request)
      expect(response.location).to include('/index?section=errors')
    end

    it 'redirects with account-not-eligible alert for no_deposit user creating dataset' do
      session[:previous_url] = '/index'
      dataset = create(:dataset)
      exception = CanCan::AccessDenied.new('Not authorized', :new, dataset)
      allow(controller).to receive(:current_user).and_return(instance_double(User, role: 'no_deposit'))
      request.env['test.exception'] = exception

      get :process_error

      expect(response).to redirect_to('/index')
      expect(flash[:alert]).to include('ACCOUNT NOT ELIGIBLE TO DEPOSIT DATA.')
    end

    it 'returns forbidden with generic authorization message for other access denied errors' do
      session[:previous_url] = '/index'
      dataset = create(:dataset)
      exception = CanCan::AccessDenied.new('Not authorized', :read, dataset)
      request.env['test.exception'] = exception

      get :process_error

      expect(response).to have_http_status(:forbidden)
      expect(flash[:alert]).to eq('You are not authorized to access the requested resource.')
    end

    it 'notifies tech team and renders 500 page for generic exceptions' do
      exception = StandardError.new('boom')
      exception.set_backtrace(['spec/backtrace_line.rb:1'])
      request.env['test.exception'] = exception
      notification = instance_double(ActionMailer::MessageDelivery, deliver_now: true)
      allow(DatabankMailer).to receive(:error).and_return(notification)

      get :process_error

      expect(DatabankMailer).to have_received(:error).with(include('boom'))
      expect(notification).to have_received(:deliver_now)
      expect(response).to have_http_status(:internal_server_error)
    end
  end
end
