require 'rails_helper'

RSpec.describe RestorationEventsController, type: :controller do
  describe 'GET #index' do
    it 'returns success and assigns restoration events' do
      event = RestorationEvent.create!(note: 'restore run one')

      get :index

      expect(response).to be_successful
      expect(assigns(:events)).to include(event)
    end
  end
end
