class NestedItemsController < ApplicationController
  before_action :set_nested_item, only: [:show, :edit, :update, :destroy]

  def index
    @nested_items = NestedItem.all
    if params.has_key?(:id)
      datafile = Datafile.find_by(web_id: params[:id])
      @nested_items = NestedItem.where(datafile_id: datafile.id) unless datafile.nil?
    end
  end

  def show
  end

  def new
    @nested_item = NestedItem.new
  end

  def edit
  end

  def create
    @nested_item = NestedItem.new(nested_item_params)

    respond_to do |format|
      if @nested_item.save
        format.html { redirect_to @nested_item, notice: 'Nested item was successfully created.' }
        format.json { render :show, status: :created, location: @nested_item }
      else
        format.html { render :new }
        format.json { render json: @nested_item.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @nested_item.update(nested_item_params)
        format.html { redirect_to @nested_item, notice: 'Nested item was successfully updated.' }
        format.json { render :show, status: :ok, location: @nested_item }
      else
        format.html { render :edit }
        format.json { render json: @nested_item.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @nested_item.destroy
    respond_to do |format|
      format.html { redirect_to nested_item_url, notice: 'Nested item was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_nested_item
      @nested_item = NestedItem.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def nested_item_params
      params.require(:nested_item).permit(:datafile_id, :parent_id, :item_name, :media_type, :size )
    end
end

