class IngestResponsesController < ApplicationController
  before_action :set_ingest_response, only: [:show, :edit, :update, :destroy]
  authorize_resource

  # GET /ingest_responses
  # GET /ingest_responses.json
  def index
    @ingest_responses = IngestResponse.all
  end

  # GET /ingest_responses/1
  # GET /ingest_responses/1.json
  def show
  end

  # GET /ingest_responses/new
  def new
    @ingest_response = IngestResponse.new
  end

  # GET /ingest_responses/1/edit
  def edit
  end

  # POST /ingest_responses
  # POST /ingest_responses.json
  def create
    @ingest_response = IngestResponse.new(ingest_response_params)

    respond_to do |format|
      if @ingest_response.save
        format.html { redirect_to @ingest_response, notice: 'Ingest response was successfully created.' }
        format.json { render :show, status: :created, location: @ingest_response }
      else
        format.html { render :new }
        format.json { render json: @ingest_response.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /ingest_responses/1
  # PATCH/PUT /ingest_responses/1.json
  def update
    respond_to do |format|
      if @ingest_response.update(ingest_response_params)
        format.html { redirect_to @ingest_response, notice: 'Ingest response was successfully updated.' }
        format.json { render :show, status: :ok, location: @ingest_response }
      else
        format.html { render :edit }
        format.json { render json: @ingest_response.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /ingest_responses/1
  # DELETE /ingest_responses/1.json
  def destroy
    @ingest_response.destroy
    respond_to do |format|
      format.html { redirect_to ingest_responses_url, notice: 'Ingest response was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_ingest_response
      @ingest_response = IngestResponse.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def ingest_response_params
      params.require(:ingest_response).permit(:as_text, :status, :response_time, :staging_key, :medusa_key, :uuid)
    end
end
