# frozen_string_literal: true

include ActionView::Helpers::NumberHelper # to pass a display value to a javascript function that adds characters to view
require "tempfile"
require "open-uri"
require "fileutils"
require "net/http"
require "browser"

class DatafilesController < ApplicationController

  before_action :set_datafile, only: [:show, :edit, :update, :destroy, :download, :record_download, :download_no_record, :download_url,
                                      :upload, :do_upload, :reset_upload, :resume_upload, :update_status, :bucket_and_key,
                                      :view, :viewtext, :filepath, :iiif_filepath, :refresh_preview]

  before_action :set_dataset, only: [:index, :show, :edit, :new, :add, :create, :destroy, :upload, :do_upload]

  # before destroy, send an email to curators if the dataset is under pre-publication review
  before_action -> { send_prepub_filechange_email(Databank::FileChangeType::DELETED) }, only: [:destroy], if: -> { @dataset.in_pre_publication_review? }

  def send_prepub_filechange_email(change_type)
    DatabankMailer.prepub_filechange(@datafile.web_id, change_type).deliver_now
  end

  # Responds to `GET /datafiles`
  # Responds to `GET /datafiles.json`
  def index
    @datafiles = @dataset.complete_datafiles
    authorize! :read, @dataset
  end

  # Responds to `GET /datafiles/:web_id`
  # Responds to `GET /datafiles/:web_id.json`
  def show
    authorize! :read, @dataset
  end

  # Responds to `GET /datafiles/new`
  def new
    authorize! :update, @dataset
    @datafile = Datafile.new
    @datafile.web_id ||= @datafile.generate_web_id
  end

  # Responds to `GET /datafiles/:web_id/edit`
  def edit
    authorize! :update, @dataset
  end

  # Responds to `GET /datasets/:id/datafiles/add`
  def add
    @datafile = Datafile.new(dataset_id: @dataset.id, binary_name: "placeholder")
    @datafile.web_id = @datafile.generate_web_id
    @datafile.save
    authorize! :update, @dataset
    respond_to do |format|
      format.html { redirect_to "/datasets/#{@dataset.key}/datafiles/#{@datafile.web_id}/upload" }
      format.json { render :edit, status: :created, location: "/datasets/#{@dataset.key}/datafiles/#{@datafile.webi_id}/upload" }
    end
  end

  # Responds to `POST /datasets/:dataset_id/datafiles`
  def create
    authorize! :update, @dataset
    @datafile = Datafile.new(dataset_id: @dataset.id)
    @datafile.web_id ||= @datafile.generate_web_id
    
    if params.has_key?(:datafile) && !params[:datafile].is_a?(String) && params[:datafile].has_key?(:tus_url)
      tus_url = params[:datafile][:tus_url]
      tus_url_arr = tus_url.split("/")
      tus_key = tus_url_arr[-1]

      @datafile.storage_root = StorageManager.instance.draft_root.name
      @datafile.binary_name = params[:datafile][:filename]
      @datafile.storage_key = tus_key
      @datafile.binary_size = params[:datafile][:size]
      @datafile.mime_type = params[:datafile][:mime_type]
      @datafile.peek_type = Databank::PeekType::NONE
      @datafile.peek_text = nil
    else
      @datafile.assign_attributes(datafile_params)
    end

    if @datafile.save
      render json: to_fileupload, content_type: request.format, :layout => false
    else
      Rails.logger.warn "error in datafile create"
      Rails.logger.warn @datafile.errors.to_yaml
      render json: @datafile.errors, status: :unprocessable_entity
    end
  end

  # Responds to `GET /datafiles/:web_id/view`
  def view
    if @datafile.current_root.root_type == :filesystem
      @datafile.with_input_file do |input_file|
        send_file input_file, type: safe_content_type(@datafile), disposition: "inline", filename: @datafile.name
      end
    else
      redirect_to(datafile_view_link(@datafile), allow_other_host: true)
    end
  end

  # Responds to `PATCH/PUT /datafiles/:web_id`
  # Responds to `PATCH/PUT /datafiles/:web_id.json`
  def update
    @datafile.assign_attributes(status: "new", upload: nil) if params[:delete_upload] == "yes"
    respond_to do |format|
      if @datafile.update(datafile_params)
        format.html { redirect_to @datafile, notice: "Datafile was successfully updated." }
        format.json { render :show, status: :ok, location: @datafile }
      else
        format.html { render :edit }
        format.json { render json: @datafile.errors, status: :unprocessable_entity }
      end
    end
  end

  # Responds to `DELETE /datafiles/:web_id`
  # Responds to `DELETE /datafiles/:web_id.json`
  def destroy
    authorize! :update, @dataset
    respond_to do |format|
      if @datafile.destroy && @dataset.save
        format.html { redirect_to edit_dataset_path(@dataset.key) }
        format.json { render json: {"confirmation" => "deleted"}, status: :ok }
      else
        format.html { redirect_to edit_dataset_path(@dataset.key) }
        format.json { render json: @datafile.errors, status: :unprocessable_entity }
      end
    end
  end

  # Responds to `GET /datasets/:dataset_id/datafiles/:web_id/upload`
  def upload; end

  # Responds to `PATCH /datasets/:dataset_id/datafiles/:web_id/upload`
  def do_upload
    unpersisted_datafile = Datafile.new(upload_params)
    unpersisted_datafile.web_id ||= @datafile.generate_web_id
    unpersisted_datafile.dataset_id = @dataset.id

    # If no file has been uploaded or the uploaded file has a different filename,
    # do a new upload from scratch

    if !@datafile.binary || !@datafile.binary.file || (@datafile.binary.file.filename != unpersisted_datafile.binary.file.filename)
      @datafile.assign_attributes(upload_params)
      @datafile.upload_status = "uploading"
      @datafile.save!
      render json: to_fileupload and return

      # If the already uploaded file has the same filename, try to resume
    else
      current_size = @datafile.binary.size
      content_range = request.headers["CONTENT-RANGE"]
      begin_of_chunk = content_range[/\ (.*?)-/, 1].to_i # "bytes 100-999999/1973660678" will return '100'

      # If the there is a mismatch between the size of the incomplete upload and the content-range in the
      # headers, then it's the wrong chunk!
      # In this case, start the upload from scratch
      unless begin_of_chunk == current_size
        @datafile.update!(upload_params)
        render json: to_fileupload and return
      end

      # Add the following chunk to the incomplete upload
      File.open(@datafile.binary.path, "ab") {|f| f.write(upload_params[:binary].read) }

      # Update the upload_file_size attribute
      @datafile.upload_file_size = @datafile.upload_file_size.nil? ? unpersisted_datafile.binary.file.size : @datafile.upload_file_size + unpersisted_datafile.binary.file.size
      @datafile.save!

      render json: to_fileupload and return
    end
  end

  # Responds to `GET /datasets/:dataset_id/datafiles/:web_id/reset_upload`
  def reset_upload
    @dataset = Dataset.find_by_key(params[:dataset_id])
    raise "Dataset not Found, params:#{params.to_yaml}" unless @dataset
    # Allow users to delete uploads only if they are incomplete
    raise StandardError, "Action not allowed" unless @datafile.upload_status == "uploading"
    @datafile.update!(status: "new", binary: nil)
    redirect_to "/datasets/#{@dataset.key}/datafiles/#{@datafile.web_id}/upload", notice: "Upload reset successfully. You can now start over"
  end

  # Responds to `GET /datasets/:dataset_id/datafiles/:web_id/resume_upload`
  def resume_upload
    @dataset = Dataset.find_by_key(params[:dataset_id])
    raise "Dataset not Found, params:#{params.to_yaml}" unless @dataset
    render json: {file: {name: "/datafiles/#{@dataset.key}/datafiles/#{@datafile.web_id}", size: @datafile.binary.size}} and return
    #render json: {file: {name: "#{@datafile.binary.file.filename}", size: @datafile.binary.size}} and return
  end

  # Responds to `PATCH /datasets/:dataset_id/datafiles/:web_id/update_status`
  def update_status
    raise ArgumentError, "Wrong status provided " + params[:status] unless @datafile.upload_status == "uploading" && params[:status] == "uploaded"
    @datafile.update!(upload_status: params[:status])
    head :ok
  end

  # Responds to `GET /datafiles/:web_id/download`
  def download
    @datafile.record_download(request.remote_ip)
    download_no_record
  end

  # Called from download action or to download a file without recording the download for drafts/curators/testing
  def download_no_record
    if Rails.env == "development" || Rails.env == "test"
      case @datafile.storage_root
      when "draft"
        root = StorageManager.instance.draft_root
      when "medusa"
        root = StorageManager.instance.medusa_root
      else
        raise "invalid storage root for datafile web_id: #{@datafile.web_id}, id: #{@datafile.id}"
      end
      expanded_key = "#{root.prefix}#{@datafile.storage_key}"
      # Use the Application.aws_client to get the object from the bucket found at @datafile.storage_root and the expanded_key, then download it to the browser
      object = Application.aws_client.get_object(bucket: root.bucket, key: expanded_key)
      send_data object.body.read, filename: @datafile.binary_name, type: safe_content_type(@datafile)
      return
    elsif @datafile.current_root.root_type == :filesystem
      @datafile.with_input_file do |input_file|
        path = @datafile.current_root.path_to(@datafile.storage_key, check_path: true)
        send_file path, filename: @datafile.binary_name, type: safe_content_type(@datafile)
      end
    else
      redirect_to(datafile_download_link(@datafile), allow_other_host: true)
    end
  end

  def to_fileupload
    {
        files:
               [
                {
                    datafileId:  @datafile.id,
                    webId:       @datafile.web_id,
                    url:         "datafiles/#{@datafile.web_id}",
                    delete_url:  "datafiles/#{@datafile.web_id}",
                    delete_type: "DELETE",
                    name:        "#{@datafile.binary_name}",
                    size:        "#{number_to_human_size(@datafile.binary_size)}"
                }
            ]
    }

  end

  # Used to record access to a datafile in cases where "download" means "access" rather than a literal download
  def record_download
    @datafile.record_download(request.remote_ip)
    render json: {status: :ok}
  end

  # Responds to `GET /datafiles/:web_id/filepath.json`
  def filepath
    if IDB_CONFIG[:aws][:s3_mode]
      render json: {filepath: "",  error: "No filepath for object in s3 bucket."}, status: :bad_request
    else
      if @datafile.filepath
        render json: {filepath: @datafile.filepath}, status: :ok
      else
        render json: {filepath: "", error: "No binary object found."}, status: :not_found
      end
    end

  end

  # Responds to `GET /datafiles/:web_id/refresh_preview.json`
  def refresh_preview
    respond_to do |format|
      if @datafile.handle_peek
        format.html { redirect_to @datafile, notice: "Refresh successfully initiated. Archive listings take time." }
        format.json { render :show, status: :ok, location: @datafile }
      else
        format.html { redirect_to @datafile }
        format.json { render json: {error: "unexpected error "}, status: :unprocessable_entity }
      end
    end
  end

  # Responds to `GET /datafiles/:web_id/viewtext.json`
  def viewtext
    render json: {peek_text: @datafile.peek_text}
  end

  # Responds to `GET /datafiles/:web_id/iiif_filepath.json`
  def iiif_filepath
    render json: {filepath: @datafile.iiif_bytestream_path}, status: :ok
  end

  # Responds to `GET /datafiles/bucket_and_key.json`
  def bucket_and_key
    if IDB_CONFIG[:aws][:s3_mode]
      render json: {bucket: @datafile.storage_root_bucket, key: @datafile.storage_key_with_prefix}, status: :ok
    else
      render json: {error: "No bucket for datafile stored on filesystem."}, status: :bad_request
    end
  end

  # Responds to `POST /datafiles/create_from_url`
  def create_from_url

    # Rails.logger.warn "inside create from url"
    # Rails.logger.warn params.to_yaml

    @dataset ||= Dataset.find_by_key(params[:dataset_key])

    @filename ||= "not_specified"
    @filesize ||= 0

    if params.has_key?(:name)
      @filename = params[:name]
    end
    if params.has_key?(:size)
      @filesize = params[:size]
    end

    @filesize_display = "#{number_to_human_size(@filesize)}"

    @datafile ||= Datafile.create(dataset_id: @dataset.id)

    @job = Delayed::Job.enqueue CreateDatafileFromRemoteJob.new(@dataset.id, @datafile, params[:url], @filename, @filesize)

    @datafile.job_id = @job.id
    @datafile.box_filename = @filename
    @datafile.box_filesize_display = @filesize_display
    @datafile.save

  end

  # Responds to `POST /datafiles/remote_content_length`
  def remote_content_length

    response = nil

    @remote_url = params["remote_url"]

    uri = URI.parse(@remote_url)

    Net::HTTP.start(uri.host, uri.port, :use_ssl => (uri.scheme == "https")) {|http|
      response = http.request_head(uri.path)
    }

    # Rails.logger.warn "content length: #{response['content-length']}"

    if response["content-length"]

      remote_content_length = Integer(response["content-length"]) rescue nil

      if remote_content_length && remote_content_length > 0

        render(json: {"status": "ok", "remote_content_length": remote_content_length}, content_type: request.format, layout: false)

      else

        render(json: {"status": "error", "error": "error getting remote content length"}, content_type: request.format, layout: false)

      end

    else
      render(json: {"status": "error", "error": "error getting content length from url"}, content_type: request.format, layout: false)
    end
  end

  # @deprecated
  def create_from_url_unknown_size

    @datafile = Datafile.new

    @dataset = Dataset.find_by_key(params[:dataset_key])
    if @dataset
      @datafile.dataset_id = @dataset.id
      @remote_url = params["remote_url"]
      @filename = params["remote_filename"]

      dir_name = "#{Rails.root}/public/uploads/#{@dataset.id}"

      FileUtils.mkdir_p(dir_name) unless File.directory?(dir_name)

      filepath = "#{dir_name}/#{@filename}"

      File.open(filepath, "wb+") do |outfile|
        uri = URI.parse(@remote_url)
        # Rails.logger.warn(uri.to_yaml)

        Net::HTTP.start(uri.host, uri.port, :use_ssl => true) {|http|
          http.request_get(uri.path) {|res|
            res.read_body {|seg|

              if File.size(outfile) < 1000000000000
                # Rails.logger.warn(seg)
                outfile << seg
              else
                @datafile.destroy
                render(json: {files: [{datafileId: 0, webId: "error", url: "error", name: "error: filesize exceeds 1TB", size: "0"}]}, content_type: request.format, :layout => false)
              end
            }
          }
        }

      end

      if File.file?(filepath)
        @datafile.binary = Rails.root.join("public/uploads/#{@dataset.id}/#{@filename}").open
      else
        raise "error in ingesting file from url"
      end
      @datafile.save!
    else
      raise "dataset not found for ingest from url"
    end

    render(json: to_fileupload, content_type: request.format, :layout => false)


  end

  # In this and datafile_view_link if possible we give a direct link to the content,
  # otherwise we direct through a controller action to get it. The difference in our
  # case is storage in S3 versus storage on the filesystem
  def datafile_download_link(datafile)
    case datafile.current_root.root_type
    when :filesystem
      download_datafile_path(datafile.web_id)
    when :s3
      datafile.current_root.presigned_get_url(datafile.storage_key, response_content_disposition: disposition("attachment", datafile),
                                                                    response_content_type:        safe_content_type(datafile))
    else
      raise "Unrecognized storage root type #{datafile.current_root.type}"
    end
  end

  # redirected from view action when the file is not in the filesystem
  def datafile_view_link(datafile)
    case datafile.current_root.root_type
    when :filesystem
      view_datafile_path(datafile)
    when :s3
      datafile.current_root.presigned_get_url(datafile.storage_key, response_content_disposition: disposition("inline", datafile),
                                                                    response_content_type:        safe_content_type(datafile))

    else
      raise "Unrecognized storage root type #{datafile.current_root.type}"
    end
  end

  def safe_content_type(datafile)
    datafile.mime_type || "application/octet-stream"
  end

  def safe_media_type(datafile)
    datafile.mime_type || "application/octet-stream"
  end

  # Utility method used in getting presigned urls for S3
  def disposition(type, datafile)

    if browser.chrome? or browser.safari?
      %Q(#{type}; filename="#{datafile.name}"; filename*=utf-8"#{CGI.escape(datafile.name)}")
    elsif browser.firefox?
      %Q(#{type}; filename="#{datafile.name}")
    else
      %Q(#{type}; filename="#{datafile.name}"; filename*=utf-8"#{CGI.escape(datafile.name)}")
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_datafile
    @datafile = Datafile.find_by_web_id(params[:id])

    raise ActiveRecord::RecordNotFound unless @datafile
  end

  # Set the dataset based on the datafile or the dataset_id parameter
  def set_dataset

    @dataset = nil

    if !@datafile && params.has_key?(:id)
      set_datafile
    end

    if @datafile
      @dataset = Dataset.find(@datafile.dataset_id)
    elsif params.has_key?(:dataset_id)
      @dataset = Dataset.find_by_key(params[:dataset_id])
    elsif params.has_key?(:datafile) && params[:datafile].has_key?(:dataset_id)
      @dataset = Dataset.find(params[:datafile][:dataset_id])
    elsif params.has_key?("datafile") && params["datafile"].has_key?("dataset_id")
      @dataset = Dataset.find(params["datafile"]["dataset_id"])
    end

    raise ActiveRecord::RecordNotFound unless @dataset

  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def datafile_params
    params.require(:datafile).permit(:description, :binary_name, :storage_root, :storage_key, :web_id, :dataset_id, :peek_text, :peek_type)
  end

  # Never trust parameters from the scary internet, only allow the white list through, more narrowly for uploads
  def upload_params
    params.require(:datafile).permit(:binary)
  end

end
