# frozen_string_literal: true

require "rails_helper"

RSpec.describe BoxImportsController, type: :controller do
  include BoxHelpers
  render_views
  let(:user) { create(:user, :admin) }
  let(:dataset) { create(:dataset) }
  let(:connection) { create_box_connection(user: user, dataset: dataset) }
  let(:client) { instance_double(BoxStorage::Client, metadata: box_metadata, picker_token: "picker-only") }
  let(:base_params) { {dataset_key: dataset.key} }

  before do
    sign_in(user)
    stub_box_s3
    stub_const("IDB_CONFIG", IDB_CONFIG.merge(box: {client_id: "box-client", client_secret: "box-secret"}))
    session[:box_connections] = {dataset.id.to_s => connection.id}
    allow(BoxStorage::Client).to receive(:new).and_return(client)
  end

  it "authorizes with state and read-only scope and validates the callback" do
    post :authorize, params: base_params
    url = URI(JSON.parse(response.body).fetch("authorization_url"))
    query = URI.decode_www_form(url.query).to_h
    expect(url.host).to eq("account.box.com")
    expect(query).to include("scope" => "root_readonly", "state" => session[:box_oauth][:state])
    expect(response.body).not_to include("box-secret")
    state = session[:box_oauth][:state]
    expect(BoxStorage::Client).to receive(:token_request).with(
      grant_type: "authorization_code", code: "auth-code", redirect_uri: box_callback_url
    ).and_return(box_tokens)
    get :callback, params: {state: state, code: "auth-code"}
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("box-oauth-result")
    expect(response.body).not_to include("box-access", "box-refresh")
  end

  it "rejects invalid OAuth state without exchanging the code" do
    post :authorize, params: base_params
    expect(BoxStorage::Client).not_to receive(:token_request)
    get :callback, params: {state: "wrong", code: "auth-code"}
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "returns only a downscoped picker token without caching" do
    get :picker, params: base_params
    expect(JSON.parse(response.body)).to eq("access_token" => "picker-only")
    expect(response.headers["Cache-Control"]).to include("no-store")
  end

  it "logs Box preview failures with the provider and action before a job is queued" do
    allow(client).to receive(:metadata).and_return(box_metadata.merge("available" => false))
    expect(Rails.logger).to receive(:warn).with(/Box import metadata rejected:/)
    expect(Rails.logger).to receive(:warn).with(/Box import preview failed: .*not available for download/)
    expect { post :preview, params: base_params.merge(file_id: "12345") }.not_to change(BoxImport, :count)
    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body)["error"]).to include("not available for download")
  end

  it "confirms validated selection, blocks a second active import, cancels and clears notices" do
    post :preview, params: base_params.merge(file_id: "12345")
    selection = JSON.parse(response.body).fetch("selection_id")
    post :create, params: base_params.merge(selection_id: selection)
    expect(response).to have_http_status(:accepted)
    import = BoxImport.last
    expect(import.source_metadata).to eq(box_metadata)
    get :index, params: base_params
    expect(JSON.parse(response.body).first["status"]).to eq("queued")
    allow(client).to receive(:metadata).and_return(box_metadata.merge("name" => "other.csv"))
    post :preview, params: base_params.merge(file_id: "12345")
    selection = JSON.parse(response.body)["selection_id"]
    expect { post :create, params: base_params.merge(selection_id: selection) }.not_to change(BoxImport, :count)
    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body)["error"]).to include("already queued")
    delete :destroy, params: base_params.merge(id: import.id)
    expect(import.reload.status).to eq("cancelled")
    expect(import.datafile).to be_nil
    expect(connection.reload.encrypted_credentials).to be_nil
    delete :dismiss, params: base_params.merge(id: import.id)
    expect(response).to have_http_status(:no_content)
    expect(BoxImport.exists?(import.id)).to be(false)
  end

  it "does not allow non-curators or another curator's authorization" do
    connection.update!(user: create(:user, :admin))
    get :picker, params: base_params
    expect(response).to have_http_status(:unprocessable_content)
    user.update!(role: "depositor", email: dataset.depositor_email)
    post :authorize, params: base_params
    expect(response).to have_http_status(:forbidden)
  end

  it "rejects forged confirmation and read-only datasets" do
    expect { post :create, params: base_params.merge(selection_id: "forged") }.not_to change(BoxImport, :count)
    expect(response).to have_http_status(:unprocessable_content)
    dataset.update!(publication_state: Databank::PublicationState::RELEASED)
    post :authorize, params: base_params
    expect(response).to have_http_status(:unprocessable_content)
  end
end
