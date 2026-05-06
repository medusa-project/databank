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

  describe "GET #add" do
    it "returns created JSON with upload location using web_id" do
      expect(controller).to receive(:render).with(
        :edit,
        hash_including(
          status: :created,
          location: a_string_matching(%r{\A/datasets/#{dataset.key}/datafiles/.+/upload\z})
        )
      )

      get :add, params: { dataset_id: dataset.key, format: :json }
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

    it "returns internal_server_error when storage object is missing" do
      missing_file_dataset = create(:dataset)
      missing_file = create(
        :datafile,
        dataset: missing_file_dataset,
        storage_root: "draft",
        storage_key: "missing/object/key",
        binary_name: "missing.txt"
      )

      allow_any_instance_of(Datafile).to receive(:record_download).and_return(true)
      allow(Application.aws_client).to receive(:get_object).and_raise(StandardError.new("NoSuchKey"))
      notification = instance_double(ActionMailer::MessageDelivery, deliver_now: true)
      allow(DatabankMailer).to receive(:error).and_return(notification)

      get :download, params: { id: missing_file.web_id }

      expect(response).to have_http_status(:internal_server_error)
      expect(DatabankMailer).to have_received(:error).with(include("NoSuchKey"))
      expect(notification).to have_received(:deliver_now)
    end
  end

  describe "POST #create_from_url" do
    it "enqueues CreateDatafileFromRemoteJob for remote file ingestion" do
      job = instance_double(Delayed::Job, id: 4321)
      allow(Delayed::Job).to receive(:enqueue).and_return(job)
      notification = instance_double(ActionMailer::MessageDelivery, deliver_now: true)
      allow(DatabankMailer).to receive(:error).and_return(notification)

      post :create_from_url, params: {
        dataset_key: dataset.key,
        url: "https://example.org/data.csv",
        name: "data.csv",
        size: "1024"
      }

      expect(Delayed::Job).to have_received(:enqueue).with(instance_of(CreateDatafileFromRemoteJob))
      expect(response).to have_http_status(:internal_server_error)
      expect(DatabankMailer).to have_received(:error)
      expect(notification).to have_received(:deliver_now)
    end
  end

  describe "GET #viewtext" do
    it "returns peek_text as JSON" do
      datafile.update!(peek_text: "preview text")

      get :viewtext, params: { id: datafile.web_id, format: :json }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq("peek_text" => "preview text")
    end
  end

  describe "GET #iiif_filepath" do
    it "returns iiif filepath as JSON" do
      allow_any_instance_of(Datafile).to receive(:iiif_bytestream_path).and_return("/tmp/iiif/path")

      get :iiif_filepath, params: { id: datafile.web_id, format: :json }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq("filepath" => "/tmp/iiif/path")
    end
  end

  describe "GET #refresh_preview" do
    it "returns ok JSON when preview refresh succeeds" do
      allow_any_instance_of(Datafile).to receive(:handle_peek).and_return(true)

      get :refresh_preview, params: { id: datafile.web_id, format: :json }

      expect(response).to have_http_status(:ok)
    end

    it "returns unprocessable_content JSON when preview refresh fails" do
      allow_any_instance_of(Datafile).to receive(:handle_peek).and_return(false)

      get :refresh_preview, params: { id: datafile.web_id, format: :json }

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)).to eq("error" => "unexpected error ")
    end
  end

  describe "GET #filepath" do
    it "returns filepath when datafile has a filesystem path" do
      config = IDB_CONFIG.deep_dup
      config[:aws] ||= {}
      config[:aws][:s3_mode] = false
      stub_const("IDB_CONFIG", config)
      allow_any_instance_of(Datafile).to receive(:filepath).and_return("/tmp/example.txt")

      get :filepath, params: { id: datafile.web_id, format: :json }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq("filepath" => "/tmp/example.txt")
    end

    it "returns not_found when no binary object is found" do
      config = IDB_CONFIG.deep_dup
      config[:aws] ||= {}
      config[:aws][:s3_mode] = false
      stub_const("IDB_CONFIG", config)
      allow_any_instance_of(Datafile).to receive(:filepath).and_return(nil)

      get :filepath, params: { id: datafile.web_id, format: :json }

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)).to eq("filepath" => "", "error" => "No binary object found.")
    end

    it "returns bad_request when running in s3 mode" do
      config = IDB_CONFIG.deep_dup
      config[:aws] ||= {}
      config[:aws][:s3_mode] = true
      stub_const("IDB_CONFIG", config)

      get :filepath, params: { id: datafile.web_id, format: :json }

      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)).to eq("filepath" => "", "error" => "No filepath for object in s3 bucket.")
    end
  end

  describe "GET #bucket_and_key" do
    it "returns bucket and key in s3 mode" do
      config = IDB_CONFIG.deep_dup
      config[:aws] ||= {}
      config[:aws][:s3_mode] = true
      stub_const("IDB_CONFIG", config)
      allow_any_instance_of(Datafile).to receive(:storage_root_bucket).and_return("bucket-a")
      allow_any_instance_of(Datafile).to receive(:storage_key_with_prefix).and_return("prefix/key")

      get :bucket_and_key, params: { dataset_id: dataset.key, id: datafile.web_id, format: :json }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq("bucket" => "bucket-a", "key" => "prefix/key")
    end

    it "returns bad_request when datafile is on filesystem" do
      config = IDB_CONFIG.deep_dup
      config[:aws] ||= {}
      config[:aws][:s3_mode] = false
      stub_const("IDB_CONFIG", config)

      get :bucket_and_key, params: { dataset_id: dataset.key, id: datafile.web_id, format: :json }

      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)).to eq("error" => "No bucket for datafile stored on filesystem.")
    end
  end

  describe "POST #remote_content_length" do
    it "returns parsed remote content length when available" do
      http = instance_double(Net::HTTP)
      allow(http).to receive(:request_head).and_return({ "content-length" => "1234" })
      allow(Net::HTTP).to receive(:start).and_yield(http)

      post :remote_content_length, params: { remote_url: "https://example.org/data.csv", format: :json }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq("status" => "ok", "remote_content_length" => 1234)
    end

    it "returns error when content-length is missing" do
      http = instance_double(Net::HTTP)
      allow(http).to receive(:request_head).and_return({})
      allow(Net::HTTP).to receive(:start).and_yield(http)

      post :remote_content_length, params: { remote_url: "https://example.org/data.csv", format: :json }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq("status" => "error", "error" => "error getting content length from url")
    end

    it "returns error when content-length cannot be parsed" do
      http = instance_double(Net::HTTP)
      allow(http).to receive(:request_head).and_return({ "content-length" => "abc" })
      allow(Net::HTTP).to receive(:start).and_yield(http)

      post :remote_content_length, params: { remote_url: "https://example.org/data.csv", format: :json }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq("status" => "error", "error" => "error getting remote content length")
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
        expect(response).to have_http_status(:unprocessable_content)
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
