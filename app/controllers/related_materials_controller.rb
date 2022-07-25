class RelatedMaterialsController < ApplicationController
  before_action :set_related_material, only: [:show, :edit, :update, :destroy]

  # GET /related_materials
  # GET /related_materials.json
  def index
    @related_materials = RelatedMaterial.all
  end

  # GET /related_materials/1
  # GET /related_materials/1.json
  def show
  end

  # GET /related_materials/new
  def new
    @related_material = RelatedMaterial.new
  end

  # GET /related_materials/1/edit
  def edit
  end

  # POST /related_materials
  # POST /related_materials.json
  def create
    @related_material = RelatedMaterial.new(related_material_params)

    respond_to do |format|
      if @related_material.save
        format.html { redirect_to @related_material, notice: 'Related material was successfully created.' }
        format.json { render :show, status: :created, location: @related_material }
      else
        format.html { render :new }
        format.json { render json: @related_material.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /related_materials/1
  # PATCH/PUT /related_materials/1.json
  def update
    respond_to do |format|
      if @related_material.update(related_material_params)
        format.html { redirect_to @related_material, notice: 'Related material was successfully updated.' }
        format.json { render :show, status: :ok, location: @related_material }
      else
        format.html { render :edit }
        format.json { render json: @related_material.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /related_materials/1
  # DELETE /related_materials/1.json
  def destroy
    @related_material.destroy
    respond_to do |format|
      format.html { redirect_to related_materials_url, notice: 'Related material was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
  # Use callbacks to share common setup or constraints between actions.
  def set_related_material
    @related_material = RelatedMaterial.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def related_material_params
    params.require(:related_material).permit(:material_type, :availability, :link, :uri, :uri_type, :citation, :dataset_id)
  end
end
