# frozen_string_literal: true

class BoxImportsController < CloudImportsController
  def authorize
    BoxImport.ensure_importable!(@dataset, current_user)
    BoxStorage::Client.ensure_configured!
    state = SecureRandom.hex(32)
    session[:box_oauth] = {state: state, dataset_id: @dataset.id, user_id: current_user.id,
                          expires_at: 10.minutes.from_now.to_i, redirect_uri: box_callback_url}
    query = URI.encode_www_form(response_type: "code", client_id: BoxStorage::Client.settings[:client_id],
                                redirect_uri: box_callback_url, state: state, scope: "root_readonly")
    render json: {authorization_url: "https://account.box.com/api/oauth2/authorize?#{query}"}
  end

  def callback
    flow = session.delete(:box_oauth)&.with_indifferent_access
    unless flow && current_user && flow[:user_id] == current_user.id &&
           flow[:expires_at].to_i > Time.current.to_i &&
           ActiveSupport::SecurityUtils.secure_compare(flow[:state].to_s, params[:state].to_s)
      raise BoxStorage::Error, "Box authorization could not be verified. Close this window and try again."
    end
    @dataset = Dataset.find(flow[:dataset_id])
    authorize! :manage, @dataset
    BoxImport.ensure_importable!(@dataset, current_user)
    if params[:error].present? || params[:code].blank?
      raise BoxStorage::Error, "Box authorization was cancelled or denied. Close this window to return to the dataset."
    end
    tokens = BoxStorage::Client.token_request(grant_type: "authorization_code", code: params[:code],
                                               redirect_uri: flow[:redirect_uri])
    record = BoxConnection.transaction do
      connection = BoxConnection.create!(user: current_user, dataset: @dataset, expires_at: 24.hours.from_now)
      connection.store_tokens!(tokens)
      connection
    end
    session[connections_key] ||= {}
    old_id = session[connections_key][@dataset.id.to_s]
    session[connections_key][@dataset.id.to_s] = record.id
    BoxConnection.find_by(id: old_id, user: current_user)&.release_if_unused!
    @oauth_success = true
    render :callback
  end

  def picker
    BoxImport.ensure_importable!(@dataset, current_user)
    render json: {access_token: BoxStorage::Client.new(connection).picker_token}
  end

  private

  def import_model
    BoxImport
  end

  def api_client
    BoxStorage::Client
  end

  def source_name
    "Box"
  end

  def selection_key
    :box_selection
  end

  def connections_key
    :box_connections
  end

  def connection_association
    :box_connection
  end

  def connection_model
    BoxConnection
  end
end
