class MedusaIngestsController < ApplicationController
  before_action :set_medusa_ingest, only: [:show, :edit, :update, :destroy]

  # GET /medusa_ingests
  # GET /medusa_ingests.json
  def index
    @medusa_ingests = MedusaIngest.order(created_at: :desc)
  end

  # GET /medusa_ingests/1
  # GET /medusa_ingests/1.json
  def show
    @ingest_responses = IngestResponse.where(staging_key: @medusa_ingest.staging_key)
  end

  # GET /medusa_ingests/new
  def new
    @medusa_ingest = MedusaIngest.new
  end

  # GET /medusa_ingests/1/edit
  def edit
  end

  # POST /medusa_ingests
  # POST /medusa_ingests.json
  def create
    @medusa_ingest = MedusaIngest.new(medusa_ingest_params)

    respond_to do |format|
      if @medusa_ingest.save
        format.html { redirect_to @medusa_ingest, notice: 'Medusa ingest was successfully created.' }
        format.json { render :show, status: :created, location: @medusa_ingest }
      else
        format.html { render :new }
        format.json { render json: @medusa_ingest.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /medusa_ingests/1
  # PATCH/PUT /medusa_ingests/1.json
  def update
    respond_to do |format|
      if @medusa_ingest.update(medusa_ingest_params)
        format.html { redirect_to @medusa_ingest, notice: 'Medusa ingest was successfully updated.' }
        format.json { render :show, status: :ok, location: @medusa_ingest }
      else
        format.html { render :edit }
        format.json { render json: @medusa_ingest.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /medusa_ingests/1
  # DELETE /medusa_ingests/1.json
  def destroy
    @medusa_ingest.destroy
    respond_to do |format|
      format.html { redirect_to medusa_ingests_url, notice: 'Medusa ingest was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def remove_draft_if_in_medusa
    MedusaIngest.remove_draft_if_in_medusa
  end

  private
  # Use callbacks to share common setup or constraints between actions.
  def set_medusa_ingest
    @medusa_ingest = MedusaIngest.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def medusa_ingest_params
    params.require(:medusa_ingest).permit(:idb_class, :idb_identifier, :staging_path, :request_status, :medusa_path, :medusa_uuid, :response_time, :error_text)
  end
end
