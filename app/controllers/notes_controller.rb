# frozen_string_literal: true

class NotesController < ApplicationController
  load_and_authorize_resource
  before_action :set_note, only: [:show, :edit, :update, :destroy]
  before_action :set_dataset, only: [:index, :show, :new, :create, :edit, :update, :destroy]

  # GET /notes
  # GET /notes.json
  def index
    authorize! :manage, @dataset
    @notes = if @dataset
               @dataset.notes
             else
               Note.all
             end
  end

  # GET /notes/1
  # GET /notes/1.json
  def show; end

  # GET /notes/new
  def new
    @note = @dataset.notes.build
  end

  # GET /notes/1/edit
  def edit; end

  # POST /notes
  # POST /notes.json
  def create
    @note = Note.new(note_params)

    respond_to do |format|
      if @note.save
        format.html { redirect_to dataset_notes_path(@dataset), notice: "Note was successfully created." }
        format.json { render :show, status: :created, location: @note }
      else
        format.html { render :new }
        format.json { render json: @note.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /notes/1
  # PATCH/PUT /notes/1.json
  def update
    respond_to do |format|
      if @note.update(note_params)
        format.html { redirect_to dataset_notes_path(@dataset), notice: "Note was successfully updated." }
        format.json { render :show, status: :ok, location: @note }
      else
        format.html { render :edit }
        format.json { render json: @note.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /notes/1
  # DELETE /notes/1.json
  def destroy
    @note.destroy
    respond_to do |format|
      format.html { redirect_to dataset_notes_path(@dataset), notice: "Note was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_note
    @note = Note.find(params[:id])
  end

  def set_dataset
    @dataset = nil
    set_note if !@note && params.has_key?(:id)
    if @datafile
      @dataset = Dataset.find(@note.dataset_id)
    elsif params.has_key?(:dataset_id)
      @dataset = Dataset.find_by(key: params[:dataset_id])
    elsif params.has_key?(:note) && params[:note].has_key?(:dataset_id)
      @dataset = Dataset.find(params[:note][:dataset_id])
    elsif params.has_key?("note") && params["note"].has_key?("dataset_id")
      @dataset = Dataset.find(params["note"]["dataset_id"])
    end
    raise ActiveRecord::RecordNotFound unless @dataset
  end

  # Only allow a list of trusted parameters through.
  def note_params
    params.require(:note).permit(:dataset_id, :body, :author)
  end
end
