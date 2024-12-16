require 'rails_helper'

RSpec.describe DatafilesController, type: :controller do

  let(:user) { create(:user) }
  let(:dataset) { Dataset.where(publication_state: "draft").first}
  let(:datafile) { dataset.datafiles.first}
  let(:valid_attributes) { attributes_for(:datafile, dataset_id: dataset.key, storage_key: datafile.storage_key, storage_root: datafile.storage_root, binary_name: "test.png") }
  let(:invalid_attributes) { { binary_name: nil } }

  before do
    #sign_in user
    allow(controller).to receive(:authorize!).and_return(true)
  end

  describe "GET #index" do
    it "returns a success response" do
      get :index, params: { dataset_id: dataset.key }
      expect(response).to be_successful
    end
  end

  describe "GET #show" do
    it "returns a success response" do
      get :show, params: { id: datafile.web_id }
      expect(response).to be_successful
    end
  end

  describe "GET #new" do
    it "returns a success response" do
      get :new, params: { dataset_id: dataset.key }
      expect(response).to be_successful
    end
  end

  describe "GET #edit" do
    it "returns a success response" do
      get :edit, params: { id: datafile.web_id }
      expect(response).to be_successful
    end
  end

  describe "GET #download" do
    # assumes at least one datafile exists, which is created in the setup
    it "returns a success response and increases tallies" do
      datafile = Datafile.first
      get :download, params: { id: datafile.web_id }
      expect(response).to be_successful
      # expect DatasetDownloadTally total to increase by 1
      expect(DatasetDownloadTally.count).to eq(1)
      # expect DayFileDownload total to increase by 1
      expect(DayFileDownload.count).to eq(1)
    end
  end

  # describe "POST #create" do
  #   context "with valid params" do

  #     it "creates a new Datafile" do
  #       sign_in user
  #       # confirm that currently signed in user has a role of "depositor"
  #       expect(controller.instance_eval{current_user.role}).to eq("depositor")
  #       expect {
  #         post :create, params: { datafile: valid_attributes }
  #         puts response.body # Print the response body for debugging
  #         puts response.status # Print the response status for debugging
  #         if assigns(:datafile).errors.any?
  #           puts assigns(:datafile).errors.full_messages # Print validation errors
  #         end
  #       }.to change(Datafile, :count).by(1)
  #     end
  #   end

  #   context "with invalid params" do
  #     it "renders a JSON response with errors for the new datafile" do
  #       post :create, params: { datafile: invalid_attributes }
  #       expect(response).to have_http_status(:unprocessable_entity)
  #       expect(response.content_type).to eq('application/json')
  #     end
  #   end
  # end

  describe "PATCH #update" do
    context "with valid params" do
      let(:new_attributes) { { description: "Updated description" } }

      it "updates the requested datafile" do
        patch :update, params: { id: datafile.web_id, datafile: new_attributes }
        datafile.reload
        expect(datafile.description).to eq("Updated description")
      end
    end
  end

  # describe "DELETE #destroy" do
  #   it "destroys the requested datafile" do
  #     datafile = Datafile.create(dataset_id: dataset.id) # create the datafile
  #     expect {
  #       delete :destroy, params: { id: datafile.web_id }
  #     }.to change(Datafile, :count).by(-1)
  #   end

  #   it "renders a JSON response with the confirmation" do
  #     delete :destroy, params: { id: datafile.web_id }
  #     expect(response).to have_http_status(:ok)
  #     expect(response.content_type).to eq('application/json')
  #   end
  # end

  # describe "GET #download" do
  #   it "records the download and initiates the download" do
  #     expect(datafile).to receive(:record_download).with(anything)
  #     get :download, params: { id: datafile.web_id }
  #     expect(response).to have_http_status(:ok)
  #   end
  # end

  # describe "GET #view" do
  #   it "renders the file inline" do
  #     get :view, params: { id: datafile.web_id }
  #     expect(response).to have_http_status(:ok)
  #   end
  # end

  # describe "GET #filepath" do
  #   context "when file is in S3" do
  #     before { allow(IDB_CONFIG[:aws]).to receive(:[]).with(:s3_mode).and_return(true) }

  #     it "returns an error message" do
  #       get :filepath, params: { id: datafile.web_id }
  #       expect(response).to have_http_status(:bad_request)
  #       expect(response.content_type).to eq('application/json')
  #     end
  #   end

  #   context "when file is on filesystem" do
  #     before { allow(IDB_CONFIG[:aws]).to receive(:[]).with(:s3_mode).and_return(false) }

  #     it "returns the filepath" do
  #       allow(datafile).to receive(:filepath).and_return("/path/to/file")
  #       get :filepath, params: { id: datafile.web_id }
  #       expect(response).to have_http_status(:ok)
  #       expect(response.content_type).to eq('application/json')
  #     end
  #   end
  # end
end
