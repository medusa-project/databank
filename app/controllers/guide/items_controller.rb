# frozen_string_literal: true

module Guide
  class ItemsController < ApplicationController
    before_action :set_guide_item, only: [:show, :edit, :update, :destroy]

    # GET /guide/items or /guide/items.json
    def index
      @guide_items = Guide::Item.order(:ordinal)
    end

    # GET /guide/items/1 or /guide/items/1.json
    def show; end

    # GET /guide/items/new
    def new
      @guide_item = Guide::Item.new
      @guide_item.section_id = params["guide_item_section_id"].to_i if params.has_key?("guide_subitem_section_id")
    end

    # GET /guide/items/1/edit
    def edit; end

    # POST /guide/items or /guide/items.json
    def create
      @guide_item = Guide::Item.new(guide_item_params)

      respond_to do |format|
        if @guide_item.save
          format.html { redirect_to @guide_item, notice: "Item was successfully created." }
          format.json { render :show, status: :created, location: @guide_item }
        else
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: @guide_item.errors, status: :unprocessable_entity }
        end
      end
    end

    # PATCH/PUT /guide/items/1 or /guide/items/1.json
    def update
      respond_to do |format|
        if @guide_item.update(guide_item_params)
          format.html { redirect_to @guide_item, notice: "Item was successfully updated." }
          format.json { render :show, status: :ok, location: @guide_item }
        else
          format.html { render :edit, status: :unprocessable_entity }
          format.json { render json: @guide_item.errors, status: :unprocessable_entity }
        end
      end
    end

    # DELETE /guide/items/1 or /guide/items/1.json
    def destroy
      @guide_item.destroy
      respond_to do |format|
        format.html { redirect_to guide_items_url, notice: "Item was successfully destroyed." }
        format.json { head :no_content }
      end
    end

    # POST /guide/items/reorder
    def reorder
      raise StandardError.new("missing parent_id for reorder method: #{params}") unless params.has_key?("parent_id")

      parent_section = Guide::Section.find_by(id: params["parent_id"].to_i)

      raise StandardError.new("Section not found: #{params}") unless parent_section

      items = Guide::Item.where(section_id: parent_section.id)
      items.each do |item|
        item.update(ordinal: params["ordinal_#{item.id}"]) if params.has_key?("ordinal_#{item.id}")
      end
      redirect_to "/guide/sections/#{parent_section.id}"
    end

    private

    # Use callbacks to share common setup or constraints between actions.
    def set_guide_item
      @guide_item = Guide::Item.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def guide_item_params
      params.require(:guide_item).permit(:section_id, :anchor, :label, :ordinal, :heading, :body, :public)
    end
  end
end
