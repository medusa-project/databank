# frozen_string_literal: true

require "rails_helper"

RSpec.describe GoogleDriveConnection, type: :model do
  include GoogleDriveHelpers

  let(:user) { create(:user, :admin) }
  let(:dataset) { create(:dataset) }
  let(:connection) { create_drive_connection(user: user, dataset: dataset) }

  it "encrypts access and refresh tokens at rest" do
    expect(connection.encrypted_credentials).not_to include("test-access-token", "test-refresh-token")
    expect(connection.reload.access_token).to eq("test-access-token")
    expect(connection.inspect).not_to include(connection.encrypted_credentials)
  end

  it "refreshes access tokens without losing a refresh token omitted by Google" do
    refreshed = Signet::OAuth2::Client.new(access_token: "new-access-token", expires_at: 1.hour.from_now)
    expect(GoogleDrive::Client).to receive(:token_request) do |client|
      expect(client.refresh_token).to eq("test-refresh-token")
      client.access_token = refreshed.access_token
      client.expires_at = refreshed.expires_at
    end
    expect(connection.access_token(force_refresh: true)).to eq("new-access-token")
    expect(connection.reload.access_token).to eq("new-access-token")
  end

  it "requires new authorization when expired" do
    connection.update!(expires_at: 1.minute.ago)
    expect { connection.access_token }.to raise_error(GoogleDrive::Error, /expired/)
  end

  it "rejects corrupted ciphertext explicitly" do
    connection.update!(encrypted_credentials: "corrupt")
    expect { connection.access_token }.to raise_error(GoogleDrive::Error, /unavailable/)
  end

  it "erases credentials when no queued or importing work needs them" do
    connection.release_if_unused!
    expect(connection.reload.encrypted_credentials).to be_nil
  end

  it "retains credentials while an import still needs them" do
    GoogleDriveImport.enqueue!(dataset: dataset, user: user, connection: connection, metadata: drive_metadata)
    connection.release_if_unused!
    expect(connection.reload.access_token).to eq("test-access-token")
  end

  it "expires abandoned imports and removes their credentials" do
    import = GoogleDriveImport.enqueue!(dataset: dataset, user: user, connection: connection, metadata: drive_metadata)
    connection.update!(expires_at: 1.minute.ago)
    GoogleDriveImport.cleanup_expired!
    expect(import.reload.status).to eq("failed")
    expect(import.datafile).to be_nil
    expect(connection.reload.encrypted_credentials).to be_nil
  end
end
