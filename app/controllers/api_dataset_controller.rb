# frozen_string_literal: true

require "fileutils"
require "digest/md5"

class ApiDatasetController < ApplicationController
  before_action :authenticate, only: [:datafile]

  skip_before_action :verify_authenticity_token, only: [:datafile]

  ##
  # Uploads a datafile to a dataset.
  # Responds to `POST /api/datasets/:dataset_key/datafile`
  def datafile
    load_dataset
    return if @dataset.nil?

    if binary_upload_request?
      handle_binary_upload
    elsif tus_upload_request?
      handle_tus_upload
    else
      render json: "invalid request", status: :internal_server_error
    end
  end

  private

  def load_dataset
    @dataset = Dataset.find_by(key: params["dataset_key"])
    return if @dataset

    Rails.logger.warn "dataset NOT FOUND during API upload to dataset_key=#{params['dataset_key']}"
    raise ActiveRecord::RecordNotFound
  end

  def binary_upload_request?
    params.has_key?("binary")
  end

  def tus_upload_request?
    params.has_key?("tus_url") && params.has_key?("filename") && params.has_key?("size")
  end

  def handle_binary_upload
    df = build_binary_datafile
    StorageManager.instance.draft_root.copy_io_to(
      df.storage_key,
      params["binary"],
      nil,
      params["binary"].size
    )
    df.save
    render_upload_success(df)
  rescue StandardError => e
    render_upload_error(e)
  end

  def build_binary_datafile
    df = Datafile.new(dataset_id: @dataset.id)
    df.web_id = df.generate_web_id
    uploaded_io = params["binary"]
    df.storage_root = StorageManager.instance.draft_root.name
    df.binary_name = uploaded_io.original_filename
    df.storage_key = File.join(df.web_id, df.binary_name)
    df.binary_size = uploaded_io.size
    df.mime_type = uploaded_io.content_type
    df
  end

  def handle_tus_upload
    df = Datafile.build_from_tus(
      dataset:  @dataset,
      tus_url:  params[:tus_url],
      filename: params[:filename],
      size:     params[:size]
    )
    df.save
    render_upload_success(df)
  rescue StandardError => e
    render_upload_error(e)
  end

  def render_upload_success(datafile)
    message = "successfully uploaded #{datafile.binary_name}\n" \
              "see in dataset at #{IDB_CONFIG[:root_url_text]}/datasets/#{@dataset.key} \n"
    render json: message, status: :ok
  end

  def render_upload_error(error)
    Rails.logger.warn error.message
    render json: "#{error.message}\n", status: :internal_server_error
  end

  protected

  ##
  # Authenticates the request using a token.
  def authenticate
    # Rails.logger.warn params
    return unless params.has_key?(:dataset_key)

    @dataset = Dataset.find_by(key: params[:dataset_key])
    if @dataset && Databank::PublicationState::DRAFT_ARRAY.include?(@dataset.publication_state)
      authenticate_token || render_unauthorized
    else
      render_not_found
    end
  end

  ##
  # Authenticates the token.
  def authenticate_token
    authenticate_or_request_with_http_token do |token, _options|
      identified_tokens = Token.where("identifier = ? AND dataset_key = ?", token, @dataset.key)
      return identified_tokens.first if identified_tokens.count == 1

      identified_tokens.destroy_all if identified_tokens.count > 1
      return nil
    end
  end

  ##
  # Renders an unauthorized response.
  def render_unauthorized
    headers["WWW-Authenticate"] = 'Token realm="Application"'
    render json: "Bad credentials", status: :unauthorized
  end

  ##
  # Renders a not found response.
  def render_not_found
    render json: "Dataset Not Found", status: :not_found
  end

  ##
  # Calculates the MD5 hash of a file.
  def md5(fname)
    md5 = Digest::MD5.new
    File.open(fname, "rb") do |f|
      # Read in 2MB chunks to limit memory usage
      md5.update chunk while chunk == f.read(2_097_152)
    end
    md5
  end
end
