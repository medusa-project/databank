# frozen_string_literal: true

# DEPRECATED, not used in the current version of the application
class ContributorsController < ApplicationController
  before_action :set_contributor, only: [:show, :edit, :update, :destroy]

  ##
  # Lists all contributors
  # Responds to `GET /contributors`
  # Responds to `GET /contributors.json`
  def index
    @contributors = Contributor.all
  end

  # Responds to `GET /contributors/1`
  # Responds to `GET /contributors/1.json`
  def show; end

  # Responds to `GET /contributors/new`
  def new
    @contributor = Contributor.new
  end

  # Responds to `GET /contributors/1/edit`
  def edit; end

  # Responds to `POST /contributors`
  # Responds to `POST /contributors.json`
  def create
    @contributor = Contributor.new(contributor_params)

    respond_to do |format|
      if @contributor.save
        format.html { redirect_to @contributor, notice: 'Contributor was successfully created.' }
        format.json { render :show, status: :created, location: @contributor }
      else
        format.html { render :new }
        format.json { render json: @contributor.errors, status: :unprocessable_entity }
      end
    end
  end

  # Responds to `PATCH/PUT /contributors/1`
  # Responds to `PATCH/PUT /contributors/1.json`
  def update
    respond_to do |format|
      if @contributor.update(contributor_params)
        format.html { redirect_to @contributor, notice: 'Contributor was successfully updated.' }
        format.json { render :show, status: :ok, location: @contributor }
      else
        format.html { render :edit }
        format.json { render json: @contributor.errors, status: :unprocessable_entity }
      end
    end
  end

  # Responds to `DELETE /contributors/1`
  # Responds to `DELETE /contributors/1.json`
  def destroy
    @contributor.destroy
    respond_to do |format|
      format.html { redirect_to contributors_url, notice: 'Contributor was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_contributor
    @contributor = Contributor.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the allow list through.
  def contributor_params
    params.require(:contributor).permit(:dataset_id, :family_name, :given_name, :institution_name, :identifier, :type_of, :row_order, :email, :row_position, :identifier_scheme)
  end
end
