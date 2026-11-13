# frozen_string_literal: true

class GoogleDriveImportsController < CloudImportsController
  def authorize
    GoogleDriveImport.ensure_importable!(@dataset, current_user)
    GoogleDrive::Client.ensure_configured!
    state = SecureRandom.hex(32)
    verifier = SecureRandom.urlsafe_base64(64)
    callback_uri = google_drive_callback_url
    session[:google_drive_oauth] = {
      state: state, verifier: verifier, dataset_id: @dataset.id, user_id: current_user.id,
      expires_at: 10.minutes.from_now.to_i, redirect_uri: callback_uri
    }
    challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
    url = GoogleDrive::Client.oauth_client(redirect_uri: callback_uri).authorization_uri(
      state: state, access_type: "offline", prompt: "consent",
      code_challenge: challenge, code_challenge_method: "S256"
    )
    render json: {authorization_url: url.to_s}
  end

  def callback
    flow = session.delete(:google_drive_oauth)&.with_indifferent_access
    unless flow && current_user && flow[:user_id] == current_user.id &&
           flow[:expires_at].to_i > Time.current.to_i &&
           ActiveSupport::SecurityUtils.secure_compare(flow[:state].to_s, params[:state].to_s)
      raise GoogleDrive::Error, "Google authorization could not be verified. Close this window and try again."
    end

    @dataset = Dataset.find(flow[:dataset_id])
    authorize! :manage, @dataset
    GoogleDriveImport.ensure_importable!(@dataset, current_user)
    if params[:error].present? || params[:code].blank?
      raise GoogleDrive::Error,
            "Google authorization was cancelled or denied. Close this window to return to the dataset."
    end

    client = GoogleDrive::Client.exchange_code(code: params[:code], redirect_uri: flow[:redirect_uri],
                                               verifier: flow[:verifier])
    connection = GoogleDriveConnection.transaction do
      record = GoogleDriveConnection.create!(user: current_user, dataset: @dataset, expires_at: 24.hours.from_now)
      record.store_tokens!(client)
      record
    end
    session[:google_drive_connections] ||= {}
    old_id = session[:google_drive_connections][@dataset.id.to_s]
    session[:google_drive_connections][@dataset.id.to_s] = connection.id
    GoogleDriveConnection.find_by(id: old_id, user: current_user)&.release_if_unused!
    @oauth_success = true
    render :callback
  end

  def picker
    GoogleDriveImport.ensure_importable!(@dataset, current_user)
    GoogleDrive::Client.ensure_configured!
    render json: {access_token: connection.access_token, api_key: GoogleDrive::Client.settings[:api_key],
                  app_id: GoogleDrive::Client.settings[:project_number].to_s}
  end

  private

  def import_model
    GoogleDriveImport
  end

  def api_client
    GoogleDrive::Client
  end

  def source_name
    "Google Drive"
  end

  def selection_key
    :google_drive_selection
  end

  def connections_key
    :google_drive_connections
  end

  def connection_association
    :google_drive_connection
  end

  def connection_model
    GoogleDriveConnection
  end
end
