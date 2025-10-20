# frozen_string_literal: true

require "open-uri"
require "net/http"
require "boxr"
require "zip"
require "zipline"
require "json"
require "pathname"

Placeholder_FacetRow = Struct.new(:value, :count)

class DatasetsController < ApplicationController
  protect_from_forgery except: [:validate_change2published]
  skip_before_action :verify_authenticity_token, only: :validate_change2published
  before_action :set_dataset, only: [:show,
                                     :edit,
                                     :update,
                                     :destroy,
                                     :download_link,
                                     :download_endNote_XML,
                                     :download_plaintext_citation,
                                     :download_BibTeX,
                                     :download_RIS,
                                     :publish,
                                     :zip_and_download_selected,
                                     :request_review,
                                     :citation_text,
                                     :serialization,
                                     :download_metrics,
                                     :confirmation_message,
                                     :get_current_token,
                                     :get_new_token,
                                     :send_to_medusa,
                                     :validate_change2published,
                                     :update_permissions,
                                     :confirm_review,
                                     :send_publication_notice,
                                     :open_in_globus,
                                     :open_in_granite,
                                     :import_from_globus,
                                     :share,
                                     :remove_sharing_link,
                                     :suppression_controls,
                                     :review_requests,
                                     :permissions,
                                     :medusa_details,
                                     :temporarily_suppress_metadata,
                                     :temporarily_suppress_files,
                                     :unsuppress_changelog,
                                     :suppress_changelog,
                                     :unsuppress,
                                     :permanently_suppress_files,
                                     :permanently_suppress_metadata,
                                     :version_request,
                                     :version_confirm,
                                     :version_acknowledge,
                                     :version_controls,
                                     :copy_version_files,
                                     :unsuppress_review,
                                     :suppress_review,
                                     :version_to_draft,
                                     :draft_to_version,
                                     :restricted
  ]

  @@num_box_ingest_deamons = 10

  include DatasetsController::Versionable
  # enable streaming responses
  include ActionController::Streaming

  # enable zipline
  include Zipline

  # Responds to `GET /datasets/:id/share`
  def share
    @dataset.create_share_code(id: @dataset.id) unless @dataset.current_share_code
    share_notice = %Q(<h3>&#9432;&nbsp;&nbsp;About this Private Sharing Link</h3><ul><li>Anybody with this link can access to your private dataset
so be careful who you share it with.</li>
<li>This link can be used at the journal office during the review process or for sharing with
collaborators to access the data files while the dataset is not public.</li>
<li>This link will expire 12 months after the date first generated or upon publication.</li>)
    respond_to do |format|
      if @dataset.current_share_code
        format.html { redirect_to dataset_path(@dataset), alert: share_notice }
        format.json { render json: {private_share_link: "#{@dataset.sharing_link}"}, status: :ok }
      else
        format.html { redirect_to dataset_path(@dataset), notice: "Error generating share link." }
        format.json { render json: {private_share_link: nil}, status: :unprocessable_entity }
      end
    end
  end

  def import_from_globus
    @dataset.import_from_globus
    render json: {}, status: :ok
  rescue StandardError => e
    render json: {error: e.message}, status: :unprocessable_entity
  end

  # GET /datasets
  # GET /datasets.json
  def index
    if current_user
      user_role = current_user.role
      user = User.find_by(email: current_user&.email)
    else
      user_role = Databank::UserRole::GUEST
      user = nil
    end
    @datasets = Dataset.select(&:metadata_public?) # used for public json response
    @title = "Datasets"
    @search = Dataset.filtered_list(user_role: user_role, user: user, params: params)
    @report = Dataset.citation_report(@search, request.original_url, current_user)
    send_data @report, filename: "report.txt" if params.has_key?("download") && params["download"] == "now"
  end

  def show
    # authorize! :read, @dataset
    @shared_by_link = (params.has_key?("code") && (params["code"] == @dataset.current_share_code))
    @datacite_fabrica_url = if Rails.env.aws_production?
                              "https://doi.datacite.org/"
                            else
                              "https://doi.test.datacite.org/"
                            end
    @completion_check = Dataset.completion_check(@dataset)
    @dataset.ensure_embargo
    @dataset.ensure_version_group
    set_file_mode
    @dataset.handle_related_materials
  end

  def suppression_action
    authorize! :manage, @dataset
    redirect_to action: params[:suppression_action]
  end

  def permissions
    authorize! :manage, @dataset
  end

  def suppression_controls
    authorize! :manage, @dataset
  end

  def version_controls
    authorize! :manage, @dataset
    @previous = @dataset.previous_idb_dataset
  end

  def review_requests
    authorize! :manage, @dataset
    @review_request = ReviewRequest.new(dataset_key: @dataset.key, requested_at: Time.zone.now)
  end

  def medusa_details
    authorize! :manage, @dataset
  end

  def update_permissions
    authorize! :manage, @dataset
    reviewer_emails = params[:reviewer_emails] || []
    editor_emails = params[:editor_emails] || []
    UserAbility.update_permissions(@dataset.key, reviewer_emails, editor_emails)

    respond_to do |format|
      if @dataset.save
        format.html { redirect_to dataset_path(@dataset.key), notice: "Permissions updated." }
        format.json { render :show, status: :ok, location: dataset_path(@dataset.key) }
      else
        format.html { redirect_to dataset_path(@dataset.key), alert: "Error attempting to update permissions." }
        format.json { render json: @dataset.errors, status: :unprocessable_entity }
      end
    end
  end

  # GET /datasets/new
  def new
    authorize! :create, Dataset
    @dataset = Dataset.new
    @dataset.publication_state = Databank::PublicationState::DRAFT
    @previous_key = params["previous"] if params.has_key?("context") && params["context"] == "version"
    @dataset.creators.build
    @dataset.funders.build
    @dataset.related_materials.build
    set_file_mode
    @title = "Deposit Agreement"
  end

  # GET /datasets/1/edit
  def edit
    authorize! :update, @dataset
    set_file_mode
    if @dataset.org_creators && @dataset.org_creators == true && !@dataset.contributors.count.positive?
      @dataset.contributors.build
    end
    @dataset.creators.build unless @dataset.creators.count.positive?
    @dataset.funders.build unless @dataset.funders.count.positive?
    @dataset.related_materials.build unless @dataset.related_materials.count.positive?
    @completion_check = Dataset.completion_check(@dataset)
    @dataset.org_creators = @dataset.org_creators || false
    # set_license(@dataset)
    @publish_modal_msg = Dataset.publish_modal_msg(dataset: @dataset)
    @dataset.embargo ||= Databank::PublicationState::Embargo::NONE

    @token = @dataset.current_token

    set_file_mode

    @funder_info_arr = FUNDER_INFO_ARR
    @license_info_arr = LICENSE_INFO_ARR

    @dataset.subject = Databank::Subject::NONE unless @dataset.subject
    if @dataset.title
      @title = "Edit #{@dataset.title}"
    else
      @title = "Edit Untitled Dataset"
    end
  end

  def get_new_token
    authorize! :update, @dataset
    @token = @dataset.new_token
    render json: {token: @token.identifier}
  end

  def get_current_token
    authorize! :update, @dataset
    if @dataset.current_token && !@dataset.current_token.nil?
      @token = @dataset.current_token
      render json: {token: @token.identifier}
    else
      @token = nil
      render json: {token: "none"}
    end
  end

  # POST /datasets
  # POST /datasets.json
  def create
    authorize! :create, Dataset
    @dataset = Dataset.new(dataset_params)
    respond_to do |format|
      if @dataset.save
        if params[:dataset].has_key?(:previous_key) && params[:dataset][:previous_key].present?
          redirect_to action: :version_request, previous_key: params[:dataset][:previous_key], id: @dataset.key
          return
        end

        format.html { redirect_to edit_dataset_path(@dataset.key) }
        format.json { render :edit, status: :created, location: edit_dataset_path(@dataset.key) }
      else
        format.html { render :new }
        format.json { render json: @dataset.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /datasets/1
  # PATCH/PUT /datasets/1.json
  def update
    authorize! :update, @dataset
    @dataset.ensure_mime_types
    @dataset.ensure_previews
    old_publication_state = @dataset.publication_state
    old_creator_state = @dataset.org_creators || false
    @dataset.release_date ||= Date.current

    respond_to do |format|
      if @dataset.update(dataset_params)
        if dataset_params[:org_creators] == "true" && old_creator_state == false
          # convert individual creators to additional contacts (contributors)
          @dataset.ind_creators_to_contributors
          params["context"] = "continue_edit"
        elsif dataset_params[:org_creators] == "false" && old_creator_state == true
          # delete all institutional creators
          @dataset.institutional_creators.delete_all
          # convert all additional contacts (contributors) to individual authors
          @dataset.contributors_to_ind_creators
          params["context"] = "continue_edit"
        end
        if params.has_key?("context") && params["context"] == "exit"
          if @dataset.publication_state == Databank::PublicationState::DRAFT
            format.html {
              redirect_to "/datasets?q=&#{CGI.escape('editor')}=#{current_user.username}&context=exit_draft"
            }
          else
            format.html {
              redirect_to "/datasets?q=&#{CGI.escape('editor')}=#{current_user.username}&context=exit_doi"
            }
          end
        elsif params.has_key?("context") && params["context"] == "publish"
          if Databank::PublicationState::DRAFT == @dataset.publication_state
            raise "invalid publication state for update-and-publish"
            # only update complete datasets
          elsif Dataset.completion_check(@dataset) == "ok"
            # set publication_state
            @dataset.publication_state = if @dataset.embargo && [Databank::PublicationState::Embargo::FILE,
                                                                 Databank::PublicationState::Embargo::METADATA].include?(@dataset.embargo)
                                           @dataset.embargo
                                         else
                                           Databank::PublicationState::RELEASED
                                         end
            if old_publication_state != Databank::PublicationState::RELEASED && @dataset.publication_state == Databank::PublicationState::RELEASED
              @dataset.release_date ||= Date.current
            end
            @dataset.save
            # send_dataset_to_medusa only sends metadata files unless old_publication_state is draft
            MedusaIngest.send_dataset_to_medusa(@dataset) if Application.server_envs.include?(Rails.env)
            if @dataset.is_test? || Rails.env.test? || Rails.env.development? || @dataset.update_doi
              format.html { redirect_to dataset_path(@dataset.key) }
              format.json { render :show, status: :ok, location: dataset_path(@dataset.key) }
            else
              format.html {
                redirect_to dataset_path(@dataset.key),
                            notice: "Error updating DataCite Metadata, details have been logged."
              }
              format.json { render json: @dataset.errors, status: :unprocessable_entity }
            end
          else # this else means completion_check was not ok within publish context
            # Rails.logger.warn Dataset.completion_check(@dataset)
            raise "Error: Cannot update published dataset with incomplete information."
          end
        elsif params.has_key?("context") && params["context"] == "continue_edit"
          format.html { redirect_to edit_dataset_path(@dataset) }
          format.json { render :edit, status: :ok, location: edit_dataset_path(@dataset) }
        else # this else means context was not set to exit or publish - this is the normal draft update
          format.html { redirect_to dataset_path(@dataset.key) }
          format.json { render :show, status: :ok, location: dataset_path(@dataset.key) }
        end
      else # this else means update failed
        format.html { render :edit }
        format.json { render json: @dataset.errors, status: :unprocessable_entity }
      end
    end
  end

  def validate_change2published
    authorize! :update, @dataset
    completion_check_message = @dataset.valid_change2published(new_params: params)
    respond_to do |format|
      format.html { render :edit, alert: completion_check_message }
      format.json { render json: {"message": completion_check_message} }
    end
  end

  # DELETE /datasets/1
  # DELETE /datasets/1.json
  def destroy
    authorize! :destroy, @dataset
    if current_user.role == Databank::UserRole::DEPOSITOR
      redirect_url = "/datasets?q=&#{CGI.escape('depositors[]')}=#{current_user.username}"
    else
      redirect_url = datasets_url
    end
    respond_to do |format|
      if @dataset.destroy_relationship_with_previous_version && @dataset.destroy
        format.html { redirect_to redirect_url, notice: "Dataset was successfully deleted." }
        format.json { render json: {status: :ok}, content_type: request.format, layout: false }
      else
        format.html { redirect_to redirect_url, alert: "Error attempting to delete dataset." }
        format.json { render json: @dataset.errors, status: :unprocessable_entity }
      end
    end
  end

  def pre_deposit
    @dataset = Dataset.new
    @title = "Pre-Deposit Considerations"
    set_file_mode
  end

  def pre_version
    @previous = Dataset.find_by(key: params[:id])
    @previous ||= Dataset.find(params[:dataset_id])
    raise ActiveRecord::RecordNotFound unless @previous
    @dataset = Dataset.new
    @title = "New Version"
    set_file_mode
  end

  def remove_sharing_link
    respond_to do |format|
      if @dataset.share_code&.destroy!
        format.html { redirect_to dataset_path(@dataset.key), notice: "Private Sharing Link has been removed." }
        format.json { render :show, status: :ok, location: dataset_path(@dataset.key) }
      else
        Rails.logger.warn ("Error removing sharing link for #{@dataset.key}")
        format.html { redirect_to dataset_path(@dataset.key), notice: "Unexpected Error" }
        format.json { render json: {error: "Unexpected Error"}, status: :unprocessable_entity }
      end
    end
  end

  def restricted
    @title = "Restricted Access"
  end

  def suppress_changelog
    authorize! :manage, @dataset
    @dataset.suppress_changelog = true
    respond_to do |format|
      if @dataset.save
        format.html { redirect_to dataset_path(@dataset.key), notice: %(Dataset changelog has suppressed.) }
        format.json { render :show, status: :ok, location: dataset_path(@dataset.key) }
      else
        format.html { redirect_to dataset_path(@dataset.key), notice: %(Error - see log.) }
        format.json { render json: @dataset.errors, status: :unprocessable_entity }
      end
    end
  end

  def unsuppress_changelog
    authorize! :manage, @dataset
    @dataset.suppress_changelog = false
    respond_to do |format|
      if @dataset.save
        format.html { redirect_to dataset_path(@dataset.key), notice: %(Dataset changelog has been unsuppressed.) }
        format.json { render :show, status: :ok, location: dataset_path(@dataset.key) }
      else
        format.html { redirect_to dataset_path(@dataset.key), notice: %(Error - see log.) }
        format.json { render json: @dataset.errors, status: :unprocessable_entity }
      end
    end
  end

  def temporarily_suppress_files
    authorize! :manage, @dataset
    @dataset.hold_state = Databank::PublicationState::TempSuppress::FILE
    respond_to do |format|
      if @dataset.save
        format.html {
          redirect_to dataset_path(@dataset.key), notice: %(Dataset files have been temporarily suppressed.)
        }
        format.json { render :show, status: :ok, location: dataset_path(@dataset.key) }
      else
        format.html { redirect_to dataset_path(@dataset.key), notice: %(Error - see log.) }
        format.json { render json: @dataset.errors, status: :unprocessable_entity }
      end
    end
  end

  def temporarily_suppress_metadata
    authorize! :manage, @dataset
    @dataset.hold_state = Databank::PublicationState::TempSuppress::METADATA
    respond_to do |format|
      if @dataset.save
        if @dataset.update_doi
          format.html {
            redirect_to dataset_path(@dataset.key),
                        notice: %(Dataset metadata and files have been temporarily suppressed.)
          }
          format.json { render :show, status: :ok, location: dataset_path(@dataset.key) }
        else
          format.html {
            redirect_to dataset_path(@dataset.key),
                        notice: %(Dataset metadata and files have been temporarily suppressed in IDB, but DataCite was not updated.)
          }
          format.json { render :show, status: :ok, location: dataset_path(@dataset.key) }
        end
      else
        format.html { redirect_to dataset_path(@dataset.key), notice: %(Error - see log.) }
        format.json { render json: @dataset.errors, status: :unprocessable_entity }
      end
    end
  end

  def unsuppress
    authorize! :manage, @dataset
    @dataset.hold_state = Databank::PublicationState::TempSuppress::NONE
    respond_to do |format|
      if @dataset.save
        if @dataset.update_doi
          format.html { redirect_to dataset_path(@dataset.key), notice: %(Dataset has been unsuppressed.) }
          format.json { render :show, status: :ok, location: dataset_path(@dataset.key) }
        else
          format.html {
            redirect_to dataset_path(@dataset.key),
                        notice: %(Dataset has been unsuppressed in IDB, but DataCite was not updated.)
          }
          format.json { render :show, status: :ok, location: dataset_path(@dataset.key) }
        end
      else
        format.html { redirect_to dataset_path(@dataset.key), notice: %(Error - see log.) }
        format.json { render json: @dataset.errors, status: :unprocessable_entity }
      end
    end
  end

  def permanently_suppress_files
    authorize! :manage, @dataset
    @dataset.publication_state = Databank::PublicationState::PermSuppress::FILE
    @dataset.hold_state = Databank::PublicationState::PermSuppress::FILE
    @dataset.tombstone_date = Date.current
    begin
      @dataset.remove_from_globus_download
      respond_to do |format|
        if @dataset.save
          format.html {
            redirect_to dataset_path(@dataset.key), notice: %(Dataset files have been permanently supressed.)
          }
          format.json { render :show, status: :ok, location: dataset_path(@dataset.key) }
        else
          format.html { redirect_to dataset_path(@dataset.key), notice: %(Error - see log.) }
          format.json { render json: @dataset.errors, status: :unprocessable_entity }
        end
      end
    rescue StandardError
      @dataset.save
      respond_to do |format|
        format.html { redirect_to dataset_path(@dataset.key), notice: %(Failed to remove from Globus Download.) }
        format.json { render json: {}, status: :unprocessable_entity }
      end
    end
  end

  def suppress_review
    @dataset.hold_state = Databank::PublicationState::TempSuppress::VERSION
    respond_to do |format|
      if @dataset.save
        format.html {
          redirect_to dataset_path(@dataset.key), notice: %(Dataset version candidate under curator review.)
        }
        format.json { render :show, status: :ok, location: dataset_path(@dataset.key) }
      else
        format.html { redirect_to dataset_path(@dataset.key), notice: %(Error - see log.) }
        format.json { render json: @dataset.errors, status: :unprocessable_entity }
      end
    end
  end

  def unsuppress_review
    @dataset.hold_state = Databank::PublicationState::TempSuppress::NONE
    respond_to do |format|
      if @dataset.save
        @dataset.send_approve_version
        format.html {
          redirect_to dataset_path(@dataset.key), notice: %(Dataset released for pre-publication review.)
        }
        format.json { render :show, status: :ok, location: dataset_path(@dataset.key) }
      else
        format.html { redirect_to dataset_path(@dataset.key), notice: %(Error - see log.) }
        format.json { render json: @dataset.errors, status: :unprocessable_entity }
      end
    end
  end

  def permanently_suppress_metadata
    authorize! :manage, @dataset
    @dataset.hold_state = Databank::PublicationState::PermSuppress::METADATA
    @dataset.publication_state = Databank::PublicationState::PermSuppress::METADATA
    @dataset.tombstone_date = Date.current.iso8601
    @dataset.embargo = Databank::PublicationState::Embargo::NONE
    @dataset.save
    begin
      @dataset.hide_doi
      @dataset.remove_from_globus_download
      respond_to do |format|
        if @dataset.save
          format.html {
            redirect_to dataset_path(@dataset.key),
                        notice: %(Dataset has been permanently supressed in Illinois Data Bank and DataCite.)
          }
          format.json { render :show, status: :ok, location: dataset_path(@dataset.key) }
        else
          format.html { redirect_to dataset_path(@dataset.key), %(Error - see log.) }
          format.json { render json: @dataset.errors, status: :unprocessable_entity }
        end
      end
    rescue StandardError
      @dataset.save
      respond_to do |format|
        format.html {
          redirect_to dataset_path(@dataset.key), alert: %(Failed to remove from DataCite or Globus Download.)
        }
        format.json { render json: {}, status: :unprocessable_entity }
      end
    end
  end

  def request_review
    authorize! :update, @dataset
    params = {}
    params["help-name"] = @dataset.depositor_name
    params["help-email"] = @dataset.depositor_email
    params["help-topic"] = "Dataset Consultation"
    params["help-dataset"] = "#{request.base_url}#{dataset_path(@dataset.key)}"
    params["help-message"] = "Pre-deposit review request"
    shoulder = if @dataset.is_test?
                 IDB_CONFIG[:datacite_test_shoulder]
               else
                 IDB_CONFIG[:datacite][:shoulder]
               end
    @dataset.identifier = "#{shoulder}#{@dataset.key}_V1" if !@dataset.identifier || @dataset.identifier == ""
    ReviewRequest.create(dataset_key: @dataset.key, requested_at: Time.zone.now)
    help_request = DatabankMailer.contact_help(params)
    help_request.deliver_now
    respond_to do |format|
      if @dataset.save
        format.html { render :confirm_review }
        format.json { render json: {status: :ok}, content_type: request.format, layout: false }
      else
        format.html {
          render :edit,
                 alert: "There was a problem updating the dataset. The error has been logged and the Research Data Service has been alerted."
        }
        format.json { render json: @dataset.errors, status: :unprocessable_entity }
      end
    end
  end

  # publishing in IDB means interacting with DataCite and Medusa
  # Responds to `POST /datasets/:id/publish`
  def publish
    authorize! :update, @dataset
    publish_attempt_result = @dataset.publish(current_user)

    respond_to do |format|
      if publish_attempt_result[:status] == "ok" && !Databank::PublicationState::PUB_ARRAY.include?(@dataset.publication_state)
        Rails.logger.warn "publish failed, but sent ok status for #{dataset.key}"
        format.html {
          redirect_to dataset_path(@dataset.key),
                      notice: "Error in publishing dataset has been logged for review by the Research Data Service."
        }
        format.json { render json: {status: :unprocessable_entity}, content_type: request.format, layout: false }
      elsif publish_attempt_result[:status] == "ok" && @dataset.save
        pub_notice = Dataset.deposit_confirmation_notice(publish_attempt_result[:old_publication_state], @dataset)
        format.html { redirect_to dataset_path(@dataset.key), notice: pub_notice }
        format.json { render json: :show, status: :ok, location: dataset_path(@dataset.key) }
      elsif publish_attempt_result[:status] == "error"
        format.html { redirect_to dataset_path(@dataset.key), notice: publish_attempt_result[:error_text] }
        format.json { render json: {status: :unprocessable_entity}, content_type: request.format, layout: false }
      else
        Rails.logger.warn "unexepected error in attempt to publish: #{publish_attempt_result}"
        format.html {
          redirect_to dataset_path(@dataset.key),
                      notice: "Error in publishing dataset has been logged for review by the Research Data Service."
        }
        format.json { render json: {status: :unprocessable_entity}, content_type: request.format, layout: false }
      end
    end
  end

  # Responds to `POST /datasets/:id/send_publication_notice`
  def send_publication_notice
    authorize! :manage, @dataset
    if @dataset.send_publication_notice
      {render: {status: :ok}, content_type: :json, layout: false}
    else
      {render: {status: :unprocessable_entity}, content_type: :json, layout: false}
    end
  end

  # Responds to `Post /datasets/:id/send_to_medusa'
  def send_to_medusa
    authorize! :update, @dataset
    ingest_record_url = MedusaIngest.send_dataset_to_medusa(@dataset)
    render json: {result: ingest_record_url || "error", status: :ok}
  end

  # Responds to `Get /datasets/:id/review_deposit_agreement' and `Get /datasets/review_deposit_agreement'
  def review_deposit_agreement
    set_dataset if params.has_key?(:id)

    if @dataset
      if StorageManager.instance.draft_root.exist?(@dataset.draft_agreement_key)
        @agreement_text = StorageManager.instance.draft_root.as_string(@dataset.draft_agreement_key)
      elsif StorageManager.instance.medusa_root.exist?(@dataset.medusa_agreement_key)
        @agreement_text = StorageManager.instance.medusa_root.as_string(@dataset.medusa_agreement_key)
      else
        raise StandardError.new("Deposit agreement not found for dataset #{@dataset.key}.")
      end
    else
      @agreement_text = File.read(Rails.root.join("public", "deposit_agreement.txt"))
    end
  end

  # Responds to `Get /datasets/:id/open_in_globus'
  def open_in_globus
    @dataset.datafiles.each do |datafile|
      datafile.record_download(request.remote_ip)
    end
    redirect_to @dataset.globus_download_dir, allow_other_host: true
  end

  # Responds to `Get /datasets/:id/open_in_granite'
  def open_in_granite
    if @dataset.datafiles && @dataset.datafiles.count.positive?
      @dataset.datafiles.each do |datafile|
        datafile.record_download(request.remote_ip)
      end
    end
    redirect_to @dataset.external_files_link, allow_other_host: true
  end

  # @deprecated
  # Was used before Medusa Download was implemented
  # Could get overwhemled by large datasets
  def zip_and_download_selected
    if @dataset.identifier.present? && @dataset.publication_state != Databank::PublicationState::DRAFT
      @dataset.complete_datafiles.each do |datafile|
        datafile.record_download(request.remote_ip) if params[:selected_files].include?(datafile.web_id)
      end
      file_name = "#{"DOI-#{@dataset.identifier}".parameterize}.zip"
    else
      file_name = "datafiles.zip"
    end
    datafiles = []
    web_ids = params[:selected_files]
    web_ids.each do |web_id|
      df = Datafile.find_by(web_id: web_id)
      datafiles.append([df.bytestream_path, df.bytestream_name]) if df
    end

    file_mappings = datafiles
                    .lazy # Lazy allows us to begin sending the download immediately instead of waiting to download everything
                    .map {|url, path| [open(url), path] }
    zipline(file_mappings, file_name)
  end

  # Responds to `Get /datasets/:id/download_link`
  # precondition: all valid web_ids in medusa
  def download_link
    return_hash = {}
    if params.has_key?("web_ids")
      web_ids_str = params["web_ids"]
      web_ids = web_ids_str.split("~")
      if !web_ids.respond_to?(:count) || web_ids.count < 1
        return_hash["status"] = "error"
        return_hash["error"] = "no web_ids after split"
        render(json: return_hash.to_json, content_type: request.format, layout: false)
      end
      web_ids.each(&:strip!)
      parametrized_doi = @dataset.identifier.parameterize
      download_hash = DownloaderClient.datafiles_download_hash(dataset:  @dataset,
                                                               web_ids:  web_ids,
                                                               zip_name: "DOI-#{parametrized_doi}")
      download_hash = download_hash.stringify_keys
      if download_hash
        if download_hash["status"] == "ok"
          web_ids.each do |web_id|
            datafile = Datafile.find_by(web_id: web_id)
            if datafile
              # Rails.logger.warn "recording datafile download for web_id #{web_id}"
              datafile.record_download(request.remote_ip)
            else
              # Rails.logger.warn "did not find datafile for web_id #{web_id}"
            end
          end
          return_hash["status"] = "ok"
          return_hash["url"] = download_hash["download_url"]
          return_hash["total_size"] = download_hash["total_size"]
        else
          return_hash["status"] = "error"
          return_hash["error"] = download_hash["error"]
        end
      else
        return_hash["status"] = "error"
        return_hash["error"] = "nil zip link returned"
      end
      render(json: return_hash.to_json, content_type: request.format, layout: false)
    else
      return_hash["status"] = "error"
      return_hash["error"] = "no web_ids in request"
      render(json: return_hash.to_json, content_type: request.format, layout: false)
    end
  end

  # Responds to `Get /datasets/:id/confirmation_message`
  def confirmation_message
    proposed_dataset = @dataset
    if params.has_key?("new_embargo_state")
      new_embargo_state = case params["new_embargo_state"]
                          when Databank::PublicationState::Embargo::FILE
                            Databank::PublicationState::Embargo::FILE
                          when Databank::PublicationState::Embargo::METADATA
                            Databank::PublicationState::Embargo::METADATA
                          else
                            Databank::PublicationState::Embargo::NONE
                          end
      proposed_dataset.embargo = new_embargo_state
      proposed_dataset.release_date = params["release_date"] || @dataset.release_date
    end
    render json: {status: :ok, message: Dataset.publish_modal_msg(dataset: proposed_dataset)}
  end

  # Responds to `Get /datasets/:id/download_endNote_XML`
  def download_endNote_XML
    t = Tempfile.new("#{@dataset.key}_endNote")

    doc = Nokogiri::XML::Document.parse(%(<?xml version="1.0" encoding="UTF-8"?><xml></xml>))

    recordsNode = doc.create_element("records")
    recordsNode.parent = doc.root

    recordNode = doc.create_element("record")
    recordNode.parent = recordsNode

    reftypeNode = doc.create_element("ref-type")
    reftypeNode.parent = recordNode
    reftypeNode["name"] = "Online Database"
    reftypeNode.content = "45"

    contributorsNode = doc.create_element("contributors")
    contributorsNode.parent = recordNode

    authorsNode = doc.create_element("authors")
    authorsNode.parent = contributorsNode

    authorNode = doc.create_element("author")
    authorNode.content = @dataset.creator_list
    authorNode.parent = authorsNode

    titlesNode = doc.create_element("titles")
    titlesNode.parent = recordNode

    titleNode = doc.create_element("title")
    titleNode.parent = titlesNode
    titleNode.content = @dataset.title

    datesNode = doc.create_element("dates")
    datesNode.parent = recordNode

    yearNode = doc.create_element("year")
    yearNode.content = @dataset.publication_year
    yearNode.parent = datesNode

    publisherNode = doc.create_element("publisher")
    publisherNode.parent = recordNode
    publisherNode.content = @dataset.publisher

    urlsNode = doc.create_element("urls")
    urlsNode.parent = recordNode

    relatedurlsNode = doc.create_element("related-urls")
    relatedurlsNode.parent = urlsNode

    if @dataset.identifier
      urlNode = doc.create_element("url")
      urlNode.parent = relatedurlsNode
      urlNode.content = "#{IDB_CONFIG[:datacite][:url_prefix]}/#{@dataset.identifier}"
    end

    electronicNode = doc.create_element("electronic-resource-num")
    electronicNode.parent = recordNode
    electronicNode.content = @dataset.identifier

    t.write(doc.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML).strip.sub("\n", ""))

    send_file t.path, type:        "application/xml",
                      disposition: "attachment",
                      filename:    "DOI-#{@dataset.identifier}.xml"

    t.close
  end

  # Responds to `Get /datasets/:id/download_RIS`
  def download_RIS
    @dataset.identifier = @dataset.key unless @dataset.identifier

    t = Tempfile.new("#{@dataset.key}_datafiles")

    t.write(%(Provider: Illinois Data Bank\nContent: text/plain; charset=%Q[us-ascii]\nTY  - DATA\nT1  - #{@dataset.title}\n))

    t.write(%(DO  - #{@dataset.identifier}\nPY  - #{@dataset.publication_year}\nUR  - #{@dataset.persistent_url}\nPB  - #{@dataset.publisher}\nER  - ))

    @dataset.identifer = @dataset.key unless @dataset.identifier

    send_file t.path, type:        "application/x-Research-Info-Systems",
                      disposition: "attachment",
                      filename:    "DOI-#{@dataset.identifier}.ris"
    t.close
  end

  # Responds to `Get /datasets/:id/download_plaintext_citation`
  def download_plaintext_citation
    t = Tempfile.new("#{@dataset.key}_citation")

    t.write(%(#{@dataset.plain_text_citation}\n))

    send_file t.path, type:        "text/plain",
                      disposition: "attachment",
                      filename:    "DOI-#{@dataset.identifier}.txt"

    t.close
  end

  # Responds to `Get /datasets/:id/download_BibTeX`
  def download_BibTeX
    @dataset.identifier = @dataset.default_identifier unless @dataset.identifier

    t = Tempfile.new("#{@dataset.key}_endNote")
    citekey = "illinoisdatabank#{@dataset.key}"

    t.write("@data{#{citekey},\ndoi = {#{@dataset.identifier}},\nurl = {#{@dataset.persistent_url_base}/#{@dataset.identifier}},\nauthor = {#{@dataset.bibtex_creator_list}},\npublisher = {#{@dataset.publisher}},\ntitle = {#{@dataset.title}},\nyear = {#{@dataset.publication_year}}
}")

    send_file t.path, type:        "application/application/x-bibtex",
                      disposition: "attachment",
                      filename:    "DOI-#{@dataset.identifier}.bib"

    t.close
  end

  # Responds to `Get /datasets/:id/citation_text`
  def citation_text
    render json: {"citation" => @dataset.plain_text_citation}
  end

  # Responds to `Get /datasets/:id/serialization`
  def serialization
    @serialization_json = recovery_serialization.to_json
    respond_to do |format|
      format.html
      format.json
    end
  end

  # Responds to `Get /datasets/:id/download_metrics`
  def download_metrics; end

  # Responds to `Get /datasets/:id/record_text`
  def record_text; end

  # Responds to `Get /datasets/:id/confirm_review`
  def confirm_review; end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_dataset
    @dataset = Dataset.find_by(key: params[:id])
    @dataset ||= Dataset.find(params[:dataset_id])
    raise ActiveRecord::RecordNotFound unless @dataset
  end

  # Non-default modes are used when the storage system is not available for writing
  def set_file_mode(mode=Databank::FileMode::WRITE_READ)
    Application.file_mode = mode
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def dataset_params
    params.require(:dataset).permit(:medusa_dataset_dir, :title, :identifier, :publisher, :license, :key, :description, :keywords, :depositor_email, :depositor_name, :corresponding_creator_name, :corresponding_creator_email, :embargo, :external_files_link, :external_files_note, :complete, :search, :dataset_version, :release_date, :is_test, :is_import, :audit_id, :removed_private, :have_permission, :internal_reviewer, :agree, :web_ids, :org_creators, :version_comment, :subject,
                                    datafiles_attributes:         [:datafile, :description, :attachment, :dataset_id, :id, :_destroy, :_update, :audit_id],
                                    creators_attributes:          [:dataset_id, :family_name, :given_name, :institution_name, :identifier, :identifier_scheme, :type_of, :row_position, :is_contact, :email, :id, :_destroy, :_update, :audit_id],
                                    contributors_attributes:      [:dataset_id, :family_name, :given_name, :identifier, :identifier_scheme, :type_of, :row_position, :is_contact, :email, :id, :_destroy, :_update, :audit_id],
                                    funders_attributes:           [:dataset_id, :code, :name, :identifier, :identifier_scheme, :grant, :id, :_destroy, :_update, :audit_id],
                                    related_materials_attributes: [:material_type, :selected_type, :availability, :link, :uri, :uri_type, :citation, :datacite_list, :dataset_id, :_destroy, :id, :_update, :audit_id, :feature, :note],
                                    version_files_attributes:     [:id, :dataset_id, :datafile_id, :selected])
  end
end
