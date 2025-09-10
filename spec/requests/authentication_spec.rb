require 'rails_helper'

RSpec.describe "Authentication", type: :request do
  fixtures :users, :datasets

  describe "User login" do
    let(:user) { users(:researcher1) }
    let(:dataset) { datasets(:draft1) }
    let(:protected_route_path) { dataset_path(dataset) }

    it "logs in the user and accesses a protected route" do
      # Log in the user
      log_in user

      # Access a protected route
      get protected_route_path
      expect(response).to have_http_status(:success)
      # expect page to have content that includes the dataset title
      expect(response.body).to include(dataset.title)

      # Verify the user is logged in by checking the session or response
      expect(session[:user_id]).to eq(user.id)
    end
  end
end