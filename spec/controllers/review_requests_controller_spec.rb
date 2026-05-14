require 'rails_helper'

RSpec.describe ReviewRequestsController, type: :controller do
  let(:admin) { create(:user, :admin) }
  let(:dataset) { create(:dataset) }
  let(:review_request) { create(:review_request, dataset: dataset) }

  before do
    sign_in admin
  end

  describe 'GET #index' do
    it 'returns success and assigns review requests' do
      review_request

      get :index

      expect(response).to be_successful
      expect(assigns(:review_requests)).to include(review_request)
    end
  end

  describe 'GET #show' do
    it 'returns success' do
      get :show, params: { id: review_request.id }

      expect(response).to be_successful
    end
  end

  describe 'GET #new' do
    it 'returns success and builds a review request' do
      get :new

      expect(response).to be_successful
      expect(assigns(:review_request)).to be_a_new(ReviewRequest)
    end
  end

  describe 'GET #edit' do
    it 'returns success' do
      get :edit, params: { id: review_request.id }

      expect(response).to be_successful
    end
  end

  describe 'POST #create' do
    it 'creates a review request and redirects to dataset page' do
      expect {
        post :create,
             params: { review_request: attributes_for(:review_request, dataset: dataset).slice(:dataset_key, :requested_at, :modified) }
      }.to change(ReviewRequest, :count).by(1)

      expect(response).to redirect_to("/datasets/#{dataset.key}")
    end

    it 'returns unprocessable content when save fails for json request' do
      allow_any_instance_of(ReviewRequest).to receive(:save).and_return(false)

      post :create,
         params: { review_request: attributes_for(:review_request, dataset: dataset).slice(:dataset_key, :requested_at, :modified) },
           format: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH #update' do
    it 'updates an existing review request' do
      patch :update,
            params: { id: review_request.id, review_request: { modified: true } }

      expect(response).to redirect_to(review_request)
      expect(review_request.reload.modified).to eq(true)
    end

    it 'returns unprocessable content when update fails for json request' do
      allow_any_instance_of(ReviewRequest).to receive(:update).and_return(false)

      patch :update,
            params: { id: review_request.id, review_request: { modified: true } },
            format: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys the requested review request' do
      review_request

      expect {
        delete :destroy, params: { id: review_request.id }
      }.to change(ReviewRequest, :count).by(-1)

      expect(response).to redirect_to(review_requests_url)
    end
  end

  describe 'GET #report' do
    it 'returns requests csv attachment' do
      review_request

      get :report

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('text/csv')
      expect(response.headers['Content-Disposition']).to include('requests.csv')
      expect(response.body).to include(dataset.key)
    end
  end
end
