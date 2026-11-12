# frozen_string_literal: true

require "rails_helper"

RSpec.describe GoogleDriveImportsController, type: :controller do
  include GoogleDriveHelpers
  render_views

  let(:user) { create(:user, :admin) }
  let(:dataset) { create(:dataset) }
  let(:connection) { create_drive_connection(user: user, dataset: dataset) }
  let(:client) { instance_double(GoogleDrive::Client, metadata: drive_metadata) }
  let(:base_params) { {dataset_key: dataset.key} }

  before do
    sign_in(user)
    stub_const("IDB_CONFIG", IDB_CONFIG.merge(google: {
      client_id: "test-client", client_secret: "test-secret", api_key: "test-api-key", project_number: "12345"
    }))
    session[:google_drive_connections] = {dataset.id.to_s => connection.id}
    allow(GoogleDrive::Client).to receive(:new).and_return(client)
  end

  it "starts offline OAuth with state and PKCE without placing tokens in the URL" do
    post :authorize, params: base_params
    expect(response).to have_http_status(:ok)
    uri = URI(JSON.parse(response.body).fetch("authorization_url"))
    query = URI.decode_www_form(uri.query).to_h
    expect(uri.host).to eq("accounts.google.com")
    expect(query).to include("scope" => GoogleDrive::Client::SCOPE, "access_type" => "offline",
                            "code_challenge_method" => "S256", "prompt" => "consent")
    expect(query["state"]).to eq(session[:google_drive_oauth][:state])
    expect(query).not_to have_key("client_secret")
  end

  it "rejects non-curators even when they can update the dataset" do
    user.update!(role: "depositor", email: dataset.depositor_email)
    post :authorize, params: base_params, format: :json
    expect(response).to have_http_status(:forbidden)
  end

  it "rejects imports into released datasets" do
    dataset.update!(publication_state: Databank::PublicationState::RELEASED)
    post :authorize, params: base_params
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "rejects invalid OAuth state without exchanging the code" do
    post :authorize, params: base_params
    expect(GoogleDrive::Client).not_to receive(:exchange_code)
    get :callback, params: {code: "test-code", state: "wrong"}
    expect(response).to have_http_status(:unprocessable_content)
    expect(session[:google_drive_oauth]).to be_nil
  end

  it "exchanges an authorized code and keeps tokens encrypted server-side" do
    post :authorize, params: base_params
    flow = session[:google_drive_oauth].dup
    tokens = Signet::OAuth2::Client.new(access_token: "callback-access", refresh_token: "callback-refresh",
                                      expires_at: 1.hour.from_now)
    expect(GoogleDrive::Client).to receive(:exchange_code).with(
      code: "test-code", redirect_uri: flow[:redirect_uri], verifier: flow[:verifier]
    ).and_return(tokens)
    get :callback, params: {code: "test-code", state: flow[:state]}
    expect(response).to have_http_status(:ok)
    saved = GoogleDriveConnection.find(session[:google_drive_connections][dataset.id.to_s])
    expect(saved.access_token).to eq("callback-access")
    expect(response.body).not_to include("callback-access", "callback-refresh")
    expect(response.headers["Cache-Control"]).to include("no-store")
    expect(session[:previous_url].to_s).not_to include("test-code")
  end

  it "returns only a short-lived access token and Picker public configuration" do
    get :picker, params: base_params
    expect(JSON.parse(response.body)).to eq(
      "access_token" => "test-access-token", "api_key" => "test-api-key", "app_id" => "12345"
    )
    expect(response.body).not_to include("test-refresh-token", "test-secret")
    expect(response.headers["Cache-Control"]).to include("no-store")
  end

  it "requires server-validated confirmation before enqueuing" do
    expect { post :create, params: base_params }.not_to change(GoogleDriveImport, :count)
    expect(response).to have_http_status(:unprocessable_content)
    post :preview, params: base_params.merge(file_id: "drive-file-123")
    preview = JSON.parse(response.body)
    expect(preview).to include("name" => "sample.csv", "size" => 5)
    expect {
      post :create, params: base_params.merge(selection_id: preview.fetch("selection_id"),
                                            name: "forged.csv", size: 123, url: "https://example.test")
    }.to change(GoogleDriveImport, :count).by(1)
    expect(response).to have_http_status(:accepted)
    expect(GoogleDriveImport.last.source_metadata).to eq(drive_metadata)
    expect(session[:google_drive_selection]).to be_nil
  end

  it "rejects duplicates on the server, including between preview and confirmation" do
    post :preview, params: base_params.merge(file_id: "drive-file-123")
    selection_id = JSON.parse(response.body).fetch("selection_id")
    dataset.datafiles.create!(binary_name: "sample.csv")
    expect { post :create, params: base_params.merge(selection_id: selection_id) }.not_to change(GoogleDriveImport, :count)
    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body)["error"]).to include("already exists")
  end

  it "rejects confirmation from a different selection or browser tab" do
    post :preview, params: base_params.merge(file_id: "drive-file-123")
    expect {
      post :create, params: base_params.merge(selection_id: "another-selection")
    }.not_to change(GoogleDriveImport, :count)
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "honors read-only mode on the server" do
    allow(Databank::Application).to receive(:file_mode).and_return(Databank::FileMode::READ_ONLY)
    post :authorize, params: base_params
    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body)["error"]).to include("disabled")
  end

  it "does not use another curator's authorization" do
    connection.update!(user: create(:user, :admin))
    get :picker, params: base_params
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "persists status and cancels queued imports without leaving credentials or a placeholder" do
    import = GoogleDriveImport.enqueue!(dataset: dataset, user: user, connection: connection, metadata: drive_metadata)
    get :index, params: base_params
    expect(JSON.parse(response.body).first).to include("status" => "queued", "bytes_downloaded" => 0)
    delete :destroy, params: base_params.merge(id: import.id)
    expect(import.reload.status).to eq("cancelled")
    expect(import.datafile).to be_nil
    expect(connection.reload.encrypted_credentials).to be_nil
  end

  it "removes final import notices without removing completed files" do
    cancelled = GoogleDriveImport.enqueue!(dataset: dataset, user: user, connection: connection, metadata: drive_metadata)
    delete :destroy, params: base_params.merge(id: cancelled.id)
    delete :dismiss, params: base_params.merge(id: cancelled.id)
    expect(response).to have_http_status(:no_content)
    expect(GoogleDriveImport.exists?(cancelled.id)).to be(false)

    complete = GoogleDriveImport.enqueue!(dataset: dataset, user: user, connection: connection,
                                          metadata: drive_metadata.merge("id" => "other", "name" => "other.txt"))
    complete.update!(status: "complete")
    delete :dismiss, params: base_params.merge(id: complete.id)
    expect(GoogleDriveImport.exists?(complete.id)).to be(false)
    expect(Datafile.exists?(complete.datafile_id)).to be(true)
  end

  it "does not remove notices for active imports" do
    import = GoogleDriveImport.enqueue!(dataset: dataset, user: user, connection: connection, metadata: drive_metadata)
    delete :dismiss, params: base_params.merge(id: import.id)
    expect(response).to have_http_status(:conflict)
    expect(import.reload.status).to eq("queued")
  end

  it "removes unused authorization when selection is cancelled" do
    delete :disconnect, params: base_params
    expect(response).to have_http_status(:no_content)
    expect(connection.reload.encrypted_credentials).to be_nil
  end

  it "requires CSRF protection for state-changing endpoints" do
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    expect(controller).not_to receive(:authorize)
    post :authorize, params: base_params, format: :json
    expect(response).to have_http_status(:forbidden)
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end
end
