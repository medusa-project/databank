# frozen_string_literal: true

module Guide
  class SectionsController < ApplicationController
    before_action :set_guide_section, only: [:show, :edit, :update, :destroy, :add_item]

    # GET /guide/sections or /guide/sections.json
    def index
      @guide_sections = Guide::Section.order(:ordinal)
    end

    def guides
      @guide_sections = if can? :manage, Guide::Section
                          Guide::Section.order(:ordinal)
                        else
                          Guide::Section.where(public: true).order(:ordinal)
                        end
      @title = "Guides"
    end

    # GET /guide/sections/1 or /guide/sections/1.json
    def show; end

    # GET /guide/sections/new
    def new
      @guide_section = Guide::Section.new
    end

    # GET /guide/sections/1/edit
    def edit; end

    # POST /guide/sections or /guide/sections.json
    def create
      @guide_section = Guide::Section.new(guide_section_params)

      respond_to do |format|
        if @guide_section.save
          format.html { redirect_to @guide_section, notice: "Section was successfully created." }
          format.json { render :show, status: :created, location: @guide_section }
        else
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: @guide_section.errors, status: :unprocessable_entity }
        end
      end
    end

    # PATCH/PUT /guide/sections/1 or /guide/sections/1.json
    def update
      respond_to do |format|
        if @guide_section.update(guide_section_params)
          format.html { redirect_to @guide_section, notice: "Section was successfully updated." }
          format.json { render :show, status: :ok, location: @guide_section }
        else
          format.html { render :edit, status: :unprocessable_entity }
          format.json { render json: @guide_section.errors, status: :unprocessable_entity }
        end
      end
    end

    # DELETE /guide/sections/1 or /guide/sections/1.json
    def destroy
      @guide_section.destroy
      respond_to do |format|
        format.html { redirect_to guide_sections_url, notice: "Section was successfully destroyed." }
        format.json { head :no_content }
      end
    end

    # POST /guide/sections/reorder
    def reorder
      Guide::Section.all.each do |section|
        section.update(ordinal: params["ordinal_#{section.id}"]) if params.has_key?("ordinal_#{section.id}")
      end
      redirect_to action: "index"
    end

    private

    # Use callbacks to share common setup or constraints between actions.
    def set_guide_section
      @guide_section = Guide::Section.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def guide_section_params
      params.require(:guide_section).permit(:anchor, :label, :ordinal, :heading, :body, :public)
    end
  end
end
