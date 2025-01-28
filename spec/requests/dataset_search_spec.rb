require 'rails_helper'

RSpec.describe "DatasetSearch", type: :request do
  fixtures :users, :datasets, :datafiles, :creators, :related_materials

  before do
    Dataset.all.each(&:ensure_creator_editors)
    Dataset.reindex
  end

  describe "GET /datasets for guest" do
    it "returns the default listing" do
      get datasets_path
      expect(response).to have_http_status(:success)
      search = Dataset.filtered_list(user_role: nil, user: nil, params: {})
      actual_identifiers = search.results.map(&:identifier)
      expected_identifiers = Dataset.select(&:metadata_public?).pluck(:identifier)
      expect(expected_identifiers & actual_identifiers).to eq(expected_identifiers)
    end
  end

  describe "GET /datasets for depositor" do
    let(:user) { users(:researcher1) }
    let(:dataset) { datasets(:draft1) }
    let(:protected_route_path) { dataset_path(dataset) }

    before do
      log_in user
    end

    it "returns the default listing" do
      get protected_route_path
      expect(response).to have_http_status(:success)
      get datasets_path
      expect(response).to have_http_status(:success)
      search = Dataset.filtered_list(user_role: Databank::UserRole::DEPOSITOR, user: user, params: {})
      expected_keys = user.datasets_user_can_view(user: user).map(&:key)
      actual_keys = search.results.map(&:key)
      expect(expected_keys & actual_keys).to eq(expected_keys)
    end
  end

  describe "GET /datasets for curator" do
    let(:user) { users(:curator1) }
    let(:dataset) { datasets(:draft1) }
    let(:protected_route_path) { dataset_path(dataset) }


    before do
      log_in user
    end

    it "returns the default listing" do
      get protected_route_path
      expect(response).to have_http_status(:success)
      get datasets_path
      expect(response).to have_http_status(:success)
      search = Dataset.filtered_list(user_role: Databank::UserRole::ADMIN, user: user, params: {})
      expected_keys = user.datasets_user_can_view(user: user).map(&:key)
      actual_keys = search.results.map(&:key)
      expect(expected_keys & actual_keys).to eq(expected_keys)
    end
  end
end