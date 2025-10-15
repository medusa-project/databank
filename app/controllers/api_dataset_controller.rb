# frozen_string_literal: true

require 'fileutils'
require 'digest/md5'

class ApiDatasetController < ApplicationController

  before_action :authenticate, only: [:datafile]

  skip_before_action :verify_authenticity_token, only: [:datafile]

  ##
  # Uploads a datafile to a dataset.
  # Responds to `POST /api/datasets/:dataset_key/datafile`
  def datafile

    @dataset = Dataset.find_by(key: params['dataset_key'])

    Rails.logger.warn "dataset NOT FOUND during API upload to dataset_key=#{params['dataset_key']}" unless @dataset

    raise ActiveRecord::RecordNotFound unless @dataset

    if params.has_key?('binary')

      begin
        df = Datafile.new(dataset_id: @dataset.id)
        df.web_id = df.generate_web_id

        uploaded_io = params['binary']

        df.storage_root = StorageManager.instance.draft_root.name
        df.binary_name = uploaded_io.original_filename
        df.storage_key = File.join(df.web_id, df.binary_name)
        df.binary_size = uploaded_io.size
        df.mime_type = uploaded_io.content_type
        # Moving the file to some safe place; as tmp files will be flushed timely
        StorageManager.instance.draft_root.copy_io_to(df.storage_key, uploaded_io, nil, uploaded_io.size)

        df.save

        render json: "successfully uploaded #{df.binary_name}\nsee in dataset at #{IDB_CONFIG[:root_url_text]}/datasets/#{@dataset.key} \n", status: :ok
      rescue StandardError => ex
        Rails.logger.warn ex.message
        render json: "#{ex.message}\n", status: :internal_server_error
      end

    elsif params.has_key?('tus_url') && params.has_key?('filename') && params.has_key?('size')

      begin
        df = Datafile.new(dataset_id: @dataset.id)
        tus_url = params[:tus_url]
        tus_url_arr = tus_url.split('/')
        tus_key = tus_url_arr[-1]

        df.storage_root = StorageManager.instance.draft_root.name
        df.binary_name = params[:filename]
        df.storage_key = tus_key
        df.binary_size = params[:size]

        df.save

        render json: "successfully uploaded #{df.binary_name}\nsee in dataset at #{IDB_CONFIG[:root_url_text]}/datasets/#{@dataset.key} \n", status: :ok
      rescue StandardError => ex
        Rails.logger.warn ex.message
        render json: "#{ex.message}\n", status: :internal_server_error
      end
    else
      render json: "invalid request", status: :internal_server_error
    end

  end

  protected

  ##
  # Authenticates the request using a token.
  def authenticate
    # Rails.logger.warn params
    if params.has_key?(:dataset_key)
      @dataset = Dataset.find_by_key(params[:dataset_key])
      if @dataset  && Databank::PublicationState::DRAFT_ARRAY.include?(@dataset.publication_state)
        authenticate_token || render_unauthorized
      else
        render_not_found
      end
    end
  end

  ##
  # Authenticates the token.
  def authenticate_token
    authenticate_or_request_with_http_token do |token, options|
      identified_tokens = Token.where("identifier = ? AND dataset_key = ?", token, @dataset.key)
      return identified_tokens.first if identified_tokens.count == 1

      identified_tokens.destroy_all if identified_tokens.count > 1
      return nil
    end
  end

  ##
  # Renders an unauthorized response.
  def render_unauthorized
    self.headers['WWW-Authenticate'] = 'Token realm="Application"'
    render json: 'Bad credentials', status: :unauthorized
  end

  ##
  # Renders a not found response.
  def render_not_found
    render json: 'Dataset Not Found', status: :not_found
  end

  ##
  # Calculates the MD5 hash of a file.
  def md5(fname)
    md5 = Digest::MD5.new
    File.open(fname, 'rb') do |f|
      # Read in 2MB chunks to limit memory usage
      while chunk = f.read(2097152)
        md5.update chunk
      end
    end
    md5
  end
end