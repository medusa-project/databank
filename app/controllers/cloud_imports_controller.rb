# frozen_string_literal: true

require "digest"
require "base64"

class CloudImportsController < ApplicationController
  protect_from_forgery with: :exception
  before_action :load_curator_dataset, except: :callback
  before_action :disable_caching
  skip_after_action :store_location
  rescue_from CloudImports::Error, with: :import_error
  rescue_from CanCan::AccessDenied do
    render json: {error: "Only curators can access #{source_name} imports during this pilot."}, status: :forbidden
  end
  rescue_from ActionController::InvalidAuthenticityToken do
    render json: {error: "Your session could not be verified. Reload the page and try again."}, status: :forbidden
  end

  def preview
    import_model.ensure_importable!(@dataset, current_user)
    metadata = api_client.validate_metadata!(api_client.new(connection).metadata(params[:file_id]))
    if @dataset.datafiles.where(binary_name: metadata.fetch("name")).exists?
      raise CloudImports::Error,
            "A file with this name already exists. Rename the source file or remove the existing dataset file."
    end

    selection_id = SecureRandom.hex(16)
    session[selection_key] =
      {id: selection_id, dataset_id: @dataset.id, connection_id: connection.id, metadata: metadata}
    render json: {selection_id: selection_id, name: metadata.fetch("name"), size: metadata.fetch("size").to_i}
  end

  def create
    selection = session[selection_key]&.with_indifferent_access
    unless selection && selection[:dataset_id] == @dataset.id && selection[:connection_id] == connection.id &&
           selection[:id] == params[:selection_id]
      raise CloudImports::Error, "Select and confirm a #{source_name} file first."
    end

    # Keep the server-validated preview snapshot; the worker rejects subsequent source changes.
    import = import_model.enqueue!(dataset: @dataset, user: current_user, connection: connection,
                                        metadata: selection.fetch(:metadata).to_h)
    session.delete(selection_key)
    render json: import.status_payload, status: :accepted
  end

  def index
    imports = import_model.where(dataset: @dataset)
    recent_ids = imports.order(created_at: :desc).limit(20).select(:id)
    visible = imports.where(status: import_model::ACTIVE_STATUSES).or(imports.where(id: recent_ids))
    render json: visible.order(created_at: :desc).map(&:status_payload)
  end

  def disconnect
    connection.release_if_unused!
    session.delete(selection_key)
    session[connections_key]&.delete(@dataset.id.to_s)
    head :no_content
  end

  def destroy
    import = import_model.where(dataset: @dataset).find(params[:id])
    import.with_lock do
      import.update!(status: "cancelled", error_message: "The import was cancelled.") if import.active?
    end
    # The worker may hold an open staging file; it notices cancellation before storing.
    import.cleanup_incomplete! unless import.status == "complete"
    import.public_send(connection_association).release_if_unused!
    render json: import.status_payload
  end

  def dismiss
    import = import_model.where(dataset: @dataset).find(params[:id])
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

    import.public_send(connection_association).release_if_unused!
    head :no_content
  end

  private

  def load_curator_dataset
    @dataset = Dataset.find_by!(key: params[:dataset_key])
    authorize! :manage, @dataset
  end

  def connection
    id = session.fetch(connections_key, {})[@dataset.id.to_s]
    @connection ||= connection_model.find_by(id: id, user: current_user, dataset: @dataset)
    raise CloudImports::Error, "Authorize #{source_name} before selecting a file." unless @connection

    @connection
  end

  def disable_caching
    response.headers["Cache-Control"] = "no-store"
    response.headers["Referrer-Policy"] = "no-referrer"
  end

  def import_error(exception)
    Rails.logger.warn("#{source_name} import #{action_name} failed: #{exception.message}")
    if action_name == "callback"
      @oauth_error = exception.message
      render :callback, status: :unprocessable_content
    else
      render json: {error: exception.message}, status: :unprocessable_content
    end
  end
end
