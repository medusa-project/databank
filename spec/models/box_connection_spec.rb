# frozen_string_literal: true

require "rails_helper"

RSpec.describe BoxConnection do
  include BoxHelpers
  let(:user) { create(:user, :admin) }
  let(:dataset) { create(:dataset) }
  let(:connection) { create_box_connection(user: user, dataset: dataset) }

  it "encrypts credentials and atomically persists the rotated refresh token" do
    expect(connection.encrypted_credentials).not_to include("box-access", "box-refresh")
    expect(BoxStorage::Client).to receive(:token_request).with(
      grant_type: "refresh_token", refresh_token: "box-refresh"
    ).and_return(box_tokens.merge("access_token" => "new-access", "refresh_token" => "rotated"))
    expect(connection.access_token(force_refresh: true)).to eq("new-access")
    expect(BoxStorage::Client).to receive(:token_request).with(
      grant_type: "refresh_token", refresh_token: "rotated"
    ).and_return(box_tokens)
    connection.reload.access_token(force_refresh: true)
  end

  it "rejects expired connections and removes credentials when unused" do
    connection.update!(expires_at: 1.minute.ago)
    expect { connection.access_token }.to raise_error(BoxStorage::Error, /expired/)
    connection.release_if_unused!
    expect(connection.reload.encrypted_credentials).to be_nil
  end
end
