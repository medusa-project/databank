class CreatorsController < ApplicationController
  before_action :set_creator, only: [:show, :edit, :update, :destroy]

  # GET /creators
  # GET /creators.json
  def index
    @creators = Creator.all
  end

  # GET /creators/1
  # GET /creators/1.json
  def show
  end

  # GET /creators/new
  def new
    @creator = Creator.new
  end

  # GET /creators/1/edit
  def edit
  end

  # POST /creators
  # POST /creators.json
  def create
    @creator = Creator.new(creator_params)

    respond_to do |format|
      if @creator.save
        format.html { redirect_to @creator, notice: 'Creator was successfully created.' }
        format.json { render :show, status: :created, location: @creator }
      else
        format.html { render :new }
        format.json { render json: @creator.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /creators/1
  # PATCH/PUT /creators/1.json
  def update
    respond_to do |format|
      if @creator.update(creator_params)
        format.html { redirect_to @creator, notice: 'Creator was successfully updated.' }
        format.json { render :show, status: :ok, location: @creator }
      else
        format.html { render :edit }
        format.json { render json: @creator.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /creators/1
  # DELETE /creators/1.json
  def destroy
    @creator.destroy
    respond_to do |format|
      format.html { redirect_to creators_url, notice: 'Creator was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def update_row_order

    @creator = Creator.find(creator_params[:creator_id])
    row_order_position_integer = Integer(creator_params[:row_order_position])
    @creator.update_attribute :row_order_position, row_order_position_integer
    @creator.save!
    render nothing: true # this is a POST action, updates sent via AJAX, no view rendered

  end

  def create_for_form
    @dataset = Dataset.find_by_key(params[:dataset_key])
    @creator = Creator.new(dataset_id: @dataset.id, is_contact: false)
    render(json: {"creator_id" => @creator.id}, content_type: request.format, :layout => false)
  end


  private
  # Use callbacks to share common setup or constraints between actions.
  def set_creator
    @creator = Creator.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def creator_params
    params.require(:creator).permit(:dataset_id, :family_name, :given_name, :institution_name, :identifier, :identifier_scheme, :email, :type_of, :is_contact, :row_position, :creator_id)
  end
end
