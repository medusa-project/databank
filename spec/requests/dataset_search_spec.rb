require 'rails_helper'

RSpec.describe "DatasetSearch", type: :request do
  # This spec depends on fixture-backed datasets/users and a populated Solr index.
  # After a test DB rebuild, fixtures are loaded by RSpec per-example, then we reindex+commit below.
  fixtures :users, :datasets, :datafiles, :creators, :related_materials

  before do
    Dataset.all.each(&:ensure_creator_editors)
    Sunspot.remove_all!(Dataset)
    Dataset.reindex
    Sunspot.commit
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

    it "escapes the search title and prevents indexing" do
      query = %q[<script>alert(1)</script>]

      get datasets_path(q: query)

      expect(response).to have_http_status(:success)
      expect(response.headers["X-Robots-Tag"]).to eq("noindex, nofollow")
      expect(response.body).to include("Datasets: &lt;script&gt;alert(1)&lt;/script&gt; | Illinois Data Bank | Illinois")
      expect(response.body).not_to include(query)
      expect(Nokogiri::HTML(response.body).at_css('input[name="q"]')["value"]).to eq(query)
    end

    it "accepts an empty search query as the default listing" do
      get datasets_path(q: "")

      expect(response).to have_http_status(:success)
      expect(response.headers["X-Robots-Tag"]).to be_nil
      expect(Nokogiri::HTML(response.body).at_css('input[name="q"]')["placeholder"]).to eq("search for datasets")
    end

    {
      "a nested query" => "q[key]=value",
      "an array query" => "q[]=value",
      "an array of nested queries" => "q[][key]=value"
    }.each do |description, query_string|
      it "rejects #{description} before searching or generating a report" do
        expect(Dataset).not_to receive(:filtered_list)
        expect(Dataset).not_to receive(:citation_report)
        expect(DatabankMailer).not_to receive(:error)

        get "/datasets?#{query_string}"

        expect(response).to have_http_status(:bad_request)
      end
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