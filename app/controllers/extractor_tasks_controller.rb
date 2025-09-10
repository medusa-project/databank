# frozen_string_literal: true

class ExtractorTasksController < ApplicationController
  load_and_authorize_resource
  before_action :set_extractor_task, only: [:show, :edit, :update, :resend, :destroy]
  before_action :set_datafile, only: [:show, :edit, :update]

  # Responds to `GET /extractor_tasks`
  # Responds to `GET /extractor_tasks.json`
  def index
    @extractor_tasks = ExtractorTask.all
  end

  # Responds to `GET /extractor_tasks/1`
  # Responds to `GET /extractor_tasks/1.json`
  def show; end

  # Responds to `GET /extractor_tasks/new`
  def new
    @extractor_task = ExtractorTask.new
  end

  # Responds to `GET /extractor_tasks/1/edit`
  def edit; end

  # Responds to `POST /extractor_tasks`
  # Responds to `POST /extractor_tasks.json`
  def create
    @extractor_task = ExtractorTask.new(extractor_task_params)

    respond_to do |format|
      if @extractor_task.save
        format.html { redirect_to @extractor_task, notice: 'Extractor task was successfully created.' }
        format.json { render :show, status: :created, location: @extractor_task }
      else
        format.html { render :new }
        format.json { render json: @extractor_task.errors, status: :unprocessable_entity }
      end
    end
  end

  # Responds to `PATCH/PUT /extractor_tasks/1`
  # Responds to `PATCH/PUT /extractor_tasks/1.json`
  def update
    respond_to do |format|
      if @extractor_task.update(extractor_task_params)
        format.html { redirect_to @extractor_task, notice: 'Extractor task was successfully updated.' }
        format.json { render :show, status: :ok, location: @extractor_task }
      else
        format.html { render :edit }
        format.json { render json: @extractor_task.errors, status: :unprocessable_entity }
      end
    end
  end

  # Responds to `DELETE /extractor_tasks/1
  # Responds to `DELETE /extractor_tasks/1.json
  def destroy
    @extractor_task.destroy
    respond_to do |format|
      format.html { redirect_to extractor_tasks_url, notice: 'Extractor task was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
  # Use callbacks to share common setup or constraints between actions.
  def set_extractor_task
    @extractor_task = ExtractorTask.find(params[:id])
  end

  def set_datafile
    set_extractor_task unless @extractor_task
    @datafile = Datafile.find_by(web_id: @extractor_task.web_id)
  end

  # Only allow a list of trusted parameters through.
  def extractor_task_params
    params.require([:extractor_task, :web_id])
  end
end
