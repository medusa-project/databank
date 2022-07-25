class FundersController < ApplicationController
  before_action :set_funder, only: [:show, :edit, :update, :destroy]

  # GET /funders
  # GET /funders.json
  def index
    @funders = Funder.all
  end

  # GET /funders/1
  # GET /funders/1.json
  def show
  end

  # GET /funders/new
  def new
    @funder = Funder.new
  end

  # GET /funders/1/edit
  def edit
  end

  # POST /funders
  # POST /funders.json
  def create
    @funder = Funder.new(funder_params)

    respond_to do |format|
      if @funder.save
        format.html { redirect_to @funder, notice: 'Funder was successfully created.' }
        format.json { render :show, status: :created, location: @funder }
      else
        format.html { render :new }
        format.json { render json: @funder.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /funders/1
  # PATCH/PUT /funders/1.json
  def update
    respond_to do |format|
      if @funder.update(funder_params)
        format.html { redirect_to @funder, notice: 'Funder was successfully updated.' }
        format.json { render :show, status: :ok, location: @funder }
      else
        format.html { render :edit }
        format.json { render json: @funder.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /funders/1
  # DELETE /funders/1.json
  def destroy
    @funder.destroy
    respond_to do |format|
      format.html { redirect_to funders_url, notice: 'Funder was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
  # Use callbacks to share common setup or constraints between actions.
  def set_funder
    @funder = Funder.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def funder_params
    params.require(:funder).permit(:name, :identifier, :identifier_scheme, :grant, :dataset_id)
  end
end
