# frozen_string_literal: true

module Guide
  class SubitemsController < ApplicationController
    before_action :set_guide_subitem, only: [:show, :edit, :update, :destroy]

    # GET /guide/subitems or /guide/subitems.json
    def index
      @guide_subitems = Guide::Subitem.order(:ordinal)
    end

    # GET /guide/subitems/1 or /guide/subitems/1.json
    def show; end

    # GET /guide/subitems/new
    def new
      @guide_subitem = Guide::Subitem.new
      @guide_subitem.item_id = params["guide_subitem_item_id"].to_i if params.has_key?("guide_subitem_item_id")
    end

    # GET /guide/subitems/1/edit
    def edit; end

    # POST /guide/subitems or /guide/subitems.json
    def create
      @guide_subitem = Guide::Subitem.new(guide_subitem_params)

      respond_to do |format|
        if @guide_subitem.save
          format.html { redirect_to @guide_subitem, notice: "Subitem was successfully created." }
          format.json { render :show, status: :created, location: @guide_subitem }
        else
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: @guide_subitem.errors, status: :unprocessable_entity }
        end
      end
    end

    # PATCH/PUT /guide/subitems/1 or /guide/subitems/1.json
    def update
      respond_to do |format|
        if @guide_subitem.update(guide_subitem_params)
          format.html { redirect_to @guide_subitem, notice: "Subitem was successfully updated." }
          format.json { render :show, status: :ok, location: @guide_subitem }
        else
          format.html { render :edit, status: :unprocessable_entity }
          format.json { render json: @guide_subitem.errors, status: :unprocessable_entity }
        end
      end
    end

    # DELETE /guide/subitems/1 or /guide/subitems/1.json
    def destroy
      @guide_subitem.destroy
      respond_to do |format|
        format.html { redirect_to guide_subitems_url, notice: "Subitem was successfully destroyed." }
        format.json { head :no_content }
      end
    end

    # POST /guide/subitems/reorder
    def reorder
      raise StandardError.new("missing parent_id for reorder method: #{params}") unless params.has_key?("parent_id")

      parent_item = Guide::Item.find_by(id: params["parent_id"].to_i)

      raise StandardError.new("Item not found not found: #{params}") unless parent_item

      subitems = Guide::Subitem.where(item_id: parent_item.id)
      subitems.each do |item|
        item.update(ordinal: params["ordinal_#{item.id}"].to_i) if params.has_key?("ordinal_#{item.id}")
      end
      redirect_to "/guide/items/#{parent_item.id}"
    end

    private

    # Use callbacks to share common setup or constraints between actions.
    def set_guide_subitem
      @guide_subitem = Guide::Subitem.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def guide_subitem_params
      params.require(:guide_subitem).permit(:item_id, :anchor, :label, :ordinal, :heading, :body, :public)
    end
  end
end
