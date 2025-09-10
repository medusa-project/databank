require 'rails_helper'

RSpec.describe DatafilesController, type: :controller do

  let(:user) { create(:user) }
  let(:dataset) { Dataset.where(publication_state: "draft").first}
  let(:datafile) { dataset.datafiles.first}
  let(:valid_attributes) { {storage_key: "fake_key", storage_root: datafile.storage_root, binary_name: "test.png" }}
  let(:invalid_attributes) { { binary_name: nil } }

  before do
    sign_in user
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

  describe "POST #create" do
    context "with valid params" do

      it "creates a new Datafile" do
        expect(controller.instance_eval{current_user.role}).to eq("depositor")
        expect {
          post :create, params: { dataset_id: dataset.key, datafile: valid_attributes }
          if !assigns(:datafile).nil? && assigns(:datafile).errors.any?
            puts assigns(:datafile).errors.full_messages # Print validation errors
          end
        }.to change(Datafile, :count).by(1)
      end
    end

    context "with invalid params" do
      it "renders a JSON response with errors for the new datafile" do
        post :create, params: { dataset_id: dataset.key, datafile: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.content_type).to eq("application/json; charset=utf-8")
      end
    end
  end

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

  describe "DELETE #destroy" do
    let(:dataset) { create(:dataset) }
    let(:datafile) { create(:datafile, dataset: dataset, binary_name: "trythis.try") }

    it "destroys the requested datafile" do
      expect(datafile).to be_present
      puts "Datafile count before delete: #{Datafile.count}"
      puts "datafile.web_id: #{datafile.web_id}"
      expect {
        delete :destroy, params: { id: datafile.web_id }
      }.to change(Datafile, :count).by(-1)
      puts "Datafile count after delete: #{Datafile.count}"
    end

    it "renders a JSON response with the confirmation" do
      delete :destroy, params: { id: datafile.web_id }
      expect(response).to have_http_status(:found)
      expect(response.content_type).to eq("text/html; charset=utf-8")
    end
  end
end
