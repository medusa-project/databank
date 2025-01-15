# frozen_string_literal: true

module DatasetsController::Versionable
  extend ActiveSupport::Concern

  # Responds to `GET /datasets/:id/version`
  def pre_version
    @previous = Dataset.find_by(key: params[:id])
    @previous ||= Dataset.find(params[:dataset_id])
    raise ActiveRecord::RecordNotFound unless @previous

    @dataset = Dataset.new
    set_file_mode
  end

  # Responds to `GET /datasets/:id/version_request`
  def version_request
    authorize! :update, @dataset
    @previous = Dataset.find_by(key: params[:previous_key])
    raise ActiveRecord::RecordNotFound unless @previous

    @dataset.add_version_metadata_copy(previous: @previous)
    @dataset.add_version_nested_objects(previous: @previous)
    @dataset.add_version_relationships(previous: @previous)
    @dataset.add_version_files(previous: @previous)
  end

  # Responds to `GET /datasets/:id/draft_to_version`
  def draft_to_version
    @dataset.publication_state = Databank::PublicationState::TempSuppress::VERSION
    respond_to do |format|
      if @dataset.save
        format.html {
          redirect_to dataset_path(@dataset.key), notice: %(Dataset designated as version-type draft.)
        }
        format.json { render :show, status: :ok, location: dataset_path(@dataset.key) }
      else
        format.html { redirect_to dataset_path(@dataset.key), notice: %(Error - see log.) }
        format.json { render json: @dataset.errors, status: :unprocessable_entity }
      end
    end
  end

  # Responds to `POST /datasets/:id/copy_version_files`
  def copy_version_files
    if @dataset.update(dataset_params)
      files_to_copy = @dataset.version_files.where(selected: true, initiated: false)
      unless files_to_copy.count.positive?
        respond_to do |format|
          format.html { render :edit, alert: "No files selected for copy." }
          format.json { render json: { error: "No files selected for copy." }, status: :unprocessable_entity }
        end
        return
      end
      @dataset.mark_version_files_initiated(files_to_copy: files_to_copy)
      @dataset.copy_version_files
      respond_to do |format|
        format.html { render :copy_version_files, notice: "File copy process initiated." }
        format.json { render json: { notice: "File copy process initiated" }, status: :ok }
      end
    else
      respond_to do |format|
        format.html { render :edit, alert: "Error attempting to copy files." }
        format.json { render json: @dataset.errors, status: :unprocessable_entity }
      end
    end
  end

  # Responds to `GET /datasets/:id/version`
  def version_confirm
    authorize! :update, @dataset
    respond_to do |format|
      if @dataset.update(dataset_params)
        @dataset.send_version_request_emails
        format.html { redirect_to dataset_path(@dataset.key), notice: "version requested" }
        format.json { render :show, status: :ok, location: dataset_path(@dataset.key) }
      else
        format.html { redirect_to dataset_path(@dataset.previous_key), notice: "error attempting to create version" }
        format.json { render json: @dataset.errors, status: :unprocessable_entity }
      end
    end
  end

  # Responds to `GET /datasets/:id/version_to_draft`
  def version_to_draft
    @dataset.publication_state = Databank::PublicationState::DRAFT
    @dataset.hold_state = Databank::PublicationState::TempSuppress::NONE
    respond_to do |format|
      if @dataset.save
        @dataset.send_approve_version
        format.html {
          redirect_to dataset_path(@dataset.key), notice: %(Dataset designated as standard draft.)
        }
        format.json { render :show, status: :ok, location: dataset_path(@dataset.key) }
      else
        format.html { redirect_to dataset_path(@dataset.key), notice: %(Error - see log.) }
        format.json { render json: @dataset.errors, status: :unprocessable_entity }
      end
    end
  end
end
