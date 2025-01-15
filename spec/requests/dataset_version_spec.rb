require 'rails_helper'

RSpec.describe "DatasetVersion", type: :request do
  fixtures :users, :datasets

  # First step in the versioning process is for the user to click a button on the most recent version of a published dataset.
  # This action sets the dataset to a new Dataset object and designates the originating dataset to the previous version of the new dataset.
  # The user is then presented with information about the versioning process.
  describe "GET /datasets/:id/version" do
    let(:user) { users(:researcher1) }
    let(:dataset) { datasets(:released1) }
    let(:protected_route_path) { dataset_path(dataset) }

    before do
      log_in user
    end

    it "sets the dataset to previous and then sets dataset to a new Dataset" do
      get version_dataset_path(dataset)
      expect(assigns(:previous)).to eq(dataset)
      expect(assigns(:dataset)).to be_a_new(Dataset)
    end
  end

  # The user has acknowedged information about the versioning process and has clicked the "Continue" button on the pre-version page.
  # A new dataset is created and previous_key is set to the key of the originating dataset.
  describe "GET /datasets/new?context=version&previous=previous_key" do
    let(:user) { users(:researcher1) }
    let(:previous) { datasets(:released1) }
    let(:protected_route_path) { dataset_path(dataset) }

    before do
      log_in user
    end

    it "creates a new dataset version based on the dataset identified as previous" do
      # A query string is appended to the URL:
      query_string = "?context=version&previous=#{previous.key}"
      # get request to the new dataset path with the query string
      get new_dataset_path + query_string
      expect(assigns(:dataset)).to be_a_new(Dataset)
      expect(assigns(:previous_key)).to eq(previous.key)
    end
  end

  # The user has accepted the deposit agreement with a previous_key present as a parameter.
  # a Post to datasets_controller #create, if made with the previous_key parameter,
  # should redirect_to action: :version_request, previous_key: params[:dataset][:previous_key], id: @dataset.key
  # describe "POST /datasets with previous_key paramater" do
  #   let(:user) { users(:researcher1) }
  #   let(:previous) { datasets(:released1) }
  #   let(:dataset) { Dataset.new() }

  #   it "redirects to version_request action" do
  #     log_in user
  #     post datasets_path, params: { dataset: { previous_key: previous.key } }
  #     expect(response).to redirect_to(version_request_dataset_path(previous_key: previous.key, id: assigns(:dataset).key))
  #   end

  # end

end