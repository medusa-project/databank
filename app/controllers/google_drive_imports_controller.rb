# frozen_string_literal: true

require "digest"
require "base64"

class GoogleDriveImportsController < ApplicationController
  protect_from_forgery with: :exception
  before_action :load_curator_dataset, except: :callback
  before_action :disable_caching
  skip_after_action :store_location
  rescue_from GoogleDrive::Error, with: :drive_error
  rescue_from CanCan::AccessDenied do
    render json: {error: "Only curators can access Google Drive imports during this pilot."}, status: :forbidden
  end
  rescue_from ActionController::InvalidAuthenticityToken do
    render json: {error: "Your session could not be verified. Reload the page and try again."}, status: :forbidden
  end

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

  def preview
    GoogleDriveImport.ensure_importable!(@dataset, current_user)
    metadata = GoogleDrive::Client.validate_metadata!(GoogleDrive::Client.new(connection).metadata(params[:file_id]))
    if @dataset.datafiles.where(binary_name: metadata.fetch("name")).exists?
      raise GoogleDrive::Error,
            "A file with this name already exists. Rename the Drive file or remove the existing dataset file."
    end

    selection_id = SecureRandom.hex(16)
    session[:google_drive_selection] =
      {id: selection_id, dataset_id: @dataset.id, connection_id: connection.id, metadata: metadata}
    render json: {selection_id: selection_id, name: metadata.fetch("name"), size: metadata.fetch("size").to_i}
  end

  def create
    selection = session[:google_drive_selection]&.with_indifferent_access
    unless selection && selection[:dataset_id] == @dataset.id && selection[:connection_id] == connection.id &&
           selection[:id] == params[:selection_id]
      raise GoogleDrive::Error, "Select and confirm a Google Drive file first."
    end

    # Keep the server-validated preview snapshot; the worker rejects subsequent source changes.
    import = GoogleDriveImport.enqueue!(dataset: @dataset, user: current_user, connection: connection,
                                        metadata: selection.fetch(:metadata).to_h)
    session.delete(:google_drive_selection)
    render json: import.status_payload, status: :accepted
  end

  def index
    imports = @dataset.google_drive_imports
    recent_ids = imports.order(created_at: :desc).limit(20).select(:id)
    visible = imports.where(status: GoogleDriveImport::ACTIVE_STATUSES).or(imports.where(id: recent_ids))
    render json: visible.order(created_at: :desc).map(&:status_payload)
  end

  def disconnect
    connection.release_if_unused!
    session.delete(:google_drive_selection)
    session[:google_drive_connections]&.delete(@dataset.id.to_s)
    head :no_content
  end

  def destroy
    import = @dataset.google_drive_imports.find(params[:id])
    import.with_lock do
      import.update!(status: "cancelled", error_message: "The import was cancelled.") if import.active?
    end
    # The worker may hold an open staging file; it notices cancellation before storing.
    import.cleanup_incomplete! unless import.status == "complete"
    import.google_drive_connection.release_if_unused!
    render json: import.status_payload
  end

  def dismiss
    import = @dataset.google_drive_imports.find(params[:id])
    removed = import.with_lock do
      next false if import.active?

      # Completed datafiles stay in the dataset; only the notice record is removed.
      import.cleanup_incomplete! unless import.status == "complete"
      import.destroy!
      true
    end
    unless removed
      render json: {error: "Cancel the import before removing its notice."}, status: :conflict
      return
    end

    import.google_drive_connection.release_if_unused!
    head :no_content
  end

  private

  def load_curator_dataset
    @dataset = Dataset.find_by!(key: params[:dataset_key])
    authorize! :manage, @dataset
  end

  def connection
    id = session.fetch(:google_drive_connections, {})[@dataset.id.to_s]
    @connection ||= GoogleDriveConnection.find_by(id: id, user: current_user, dataset: @dataset)
    raise GoogleDrive::Error, "Authorize Google Drive before selecting a file." unless @connection

    @connection
  end

  def disable_caching
    response.headers["Cache-Control"] = "no-store"
    response.headers["Referrer-Policy"] = "no-referrer"
  end

  def drive_error(exception)
    if action_name == "callback"
      @oauth_error = exception.message
      render :callback, status: :unprocessable_content
    else
      render json: {error: exception.message}, status: :unprocessable_content
    end
  end
end
