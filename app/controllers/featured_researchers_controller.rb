class FeaturedResearchersController < ApplicationController

  authorize_resource
  skip_load_and_authorize_resource :only => [:show, :index]
  before_action :set_featured_researcher, only: [:show, :preview, :edit, :update, :destroy]

  # GET /featured_researchers
  # GET /featured_researchers.json
  def index

    if current_user && current_user.role && current_user.role == "admin"
      @featured_researchers = FeaturedResearcher.all
    else
      active_featured_researchers = FeaturedResearcher.where(is_active: true)
      @featured_researchers = active_featured_researchers.order("RANDOM()")
    end

  end

  # GET /featured_researchers/1
  # GET /featured_researchers/1.json
  def show
  end

  def preview
  end

  # GET /featured_researchers/new
  def new
    @featured_researcher = FeaturedResearcher.new
  end

  # GET /featured_researchers/1/edit
  def edit
  end

  # POST /featured_researchers
  # POST /featured_researchers.json
  def create
    @featured_researcher = FeaturedResearcher.new(featured_researcher_params)

    respond_to do |format|
      if @featured_researcher.save
        format.html { render :preview }
        format.json { render json: to_fileupload, content_type: request.format, :layout => false }
      else
        format.html { render :new }
        format.json { render json: @featured_researcher.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /featured_researchers/1
  # PATCH/PUT /featured_researchers/1.json
  def update
    respond_to do |format|
      if @featured_researcher.update(featured_researcher_params)
        format.html { render :preview }
        format.json { render json: to_fileupload, content_type: request.format, :layout => false }
      else
        format.html { render :edit }
        format.json { render json: @featured_researcher.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /featured_researchers/1
  # DELETE /featured_researchers/1.json
  def destroy
    @featured_researcher.destroy
    respond_to do |format|
      format.html { redirect_to featured_researchers_url, notice: 'Featured researcher entry was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_featured_researcher
      @featured_researcher = FeaturedResearcher.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def featured_researcher_params
      params.require(:featured_researcher).permit(:name, :question, :dataset_url, :article_url, :bio, :testimonial, :photo_url, :is_active)
    end

    def to_fileupload
      {
          files:
              [
                  {
                      featureid: @featured_researcher.id,
                      image_url: @featured_researcher.binary_url,
                      url: featured_researcher_url,
                      delete_url: featured_researchers_url,
                      delete_type: "DELETE",
                      name: "#{@featured_researcher.binary.file.filename}",
                      size: "#{number_to_human_size(@featured_researcher.binary.size)}"
                  }
              ]
      }

    end
end
