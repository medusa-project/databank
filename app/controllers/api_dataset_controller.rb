require 'fileutils'
require 'digest/md5'

class ApiDatasetController < ApplicationController

  before_action :authenticate, only: [:datafile]

  skip_before_action :verify_authenticity_token, only: [:datafile]

  def datafile

    @dataset = Dataset.find_by_key(params['dataset_key'])

    raise ActiveRecord::RecordNotFound unless @dataset

    # Rails.logger.warn params.to_yaml

    if params.has_key?('binary')

      begin
        df = Datafile.create(dataset_id: @dataset.id)

        uploaded_io = params['binary']

        df.storage_root = StorageManager.instance.draft_root.name
        df.binary_name = uploaded_io.original_filename
        df.storage_key = File.join(df.web_id, df.binary_name)
        df.binary_size = uploaded_io.size
        df.mime_type = uploaded_io.content_type

        # Moving the file to some safe place; as tmp files will be flushed timely
        StorageManager.instance.draft_root.copy_io_to(df.storage_key, uploaded_io, nil, uploaded_io.size)

        df.save

        render json: "successfully uploaded #{df.binary_name}\nsee in dataset at #{IDB_CONFIG[:root_url_text]}/datasets/#{@dataset.key} \n", status: 200
      rescue Exception => ex
        Rails.logger.warn ex.message
        render json: "#{ex.message}\n", status: 500
      end

    elsif params.has_key?('tus_url') && params.has_key?('filename') && params.has_key?('size')

      begin
        df = Datafile.create(dataset_id: @dataset.id)
        tus_url = params[:tus_url]
        tus_url_arr = tus_url.split('/')
        tus_key = tus_url_arr[-1]

        df.storage_root = StorageManager.instance.draft_root.name
        df.binary_name = params[:filename]
        df.storage_key = tus_key
        df.binary_size = params[:size]

        df.save

        render json: "successfully uploaded #{df.binary_name}\nsee in dataset at #{IDB_CONFIG[:root_url_text]}/datasets/#{@dataset.key} \n", status: 200
      rescue Exception => ex
        Rails.logger.warn ex.message
        render json: "#{ex.message}\n", status: 500
      end
    else
      render json: "invalid request", status: 500
    end

  end

  protected

  def authenticate
    # Rails.logger.warn params
    if params.has_key?(:dataset_key)
      @dataset = Dataset.find_by_key(params[:dataset_key])
      if @dataset  && @dataset.publication_state == Databank::PublicationState::DRAFT
        authenticate_token || render_unauthorized
      else
        render_not_found
      end
    end
  end

  def authenticate_token
    authenticate_or_request_with_http_token do |token, options|
      identified_tokens = Token.where("identifier = ? AND dataset_key = ?", token, @dataset.key)
      if identified_tokens.count == 1
        return identified_tokens.first
      elsif identified_token > 1
        identified_tokens.destroy_all
        return nil
      else
        return nil
      end
    end
  end

  def render_unauthorized
    self.headers['WWW-Authenticate'] = 'Token realm="Application"'
    render json: 'Bad credentials', status: 401
  end

  def render_not_found
    render json: 'Dataset Not Found', status: 404
  end

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
