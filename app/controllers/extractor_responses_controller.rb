# frozen_string_literal: true

class ExtractorResponsesController < ApplicationController
  before_action :set_extractor_response, only: %i[ show edit update destroy ]

  # Responds to `GET /extractor_responses or /extractor_responses.json
  def index
    @extractor_responses = ExtractorResponse.all
  end

  # Responds to `GET /extractor_responses/1 or /extractor_responses/1.json
  def show; end

  # Responds to `GET /extractor_responses/new
  def new
    @extractor_response = ExtractorResponse.new
  end

  # Responds to `GET /extractor_responses/1/edit
  def edit; end

  # Responds to `POST /extractor_responses or /extractor_responses.json
  def create
    @extractor_response = ExtractorResponse.new(extractor_response_params)

    respond_to do |format|
      if @extractor_response.save
        format.html { redirect_to @extractor_response, notice: "Extractor response was successfully created." }
        format.json { render :show, status: :created, location: @extractor_response }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @extractor_response.errors, status: :unprocessable_entity }
      end
    end
  end

  # Responds to `PATCH/PUT /extractor_responses/1 or /extractor_responses/1.json
  def update
    respond_to do |format|
      if @extractor_response.update(extractor_response_params)
        format.html { redirect_to @extractor_response, notice: "Extractor response was successfully updated." }
        format.json { render :show, status: :ok, location: @extractor_response }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @extractor_response.errors, status: :unprocessable_entity }
      end
    end
  end

  # Responds to `DELETE /extractor_responses/1 or /extractor_responses/1.json
  def destroy
    @extractor_response.destroy
    respond_to do |format|
      format.html { redirect_to extractor_responses_url, notice: "Extractor response was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
  # Use callbacks to share common setup or constraints between actions.
  def set_extractor_response
    @extractor_response = ExtractorResponse.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def extractor_response_params
    params.require(:extractor_response).permit(:extractor_task_id, :web_id, :status, :peek_type, :peek_text)
  end
end
