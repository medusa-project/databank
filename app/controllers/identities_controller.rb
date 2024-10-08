# frozen_string_literal: true

class IdentitiesController < ApplicationController
  load_and_authorize_resource
  skip_authorize_resource only: %i[login register]
  before_action :set_identity, only: %i[show edit update destroy]

  # Responds to `GET /identities`
  # Responds to `GET /identities.json`
  def index
    @identities = Identity.all
  end

  # Responds to `GET /identities/1`
  # Responds to `GET /identities/1.json`
  def show; end

  # Responds to `GET /identities/new`
  def new
    redirect_to action: "register"
  end

  # Responds to `GET /identities/register`
  def register; end

  # Responds to `GET /identities/login`
  def login; end

  # Responds to `GET /identities/1/edit`
  def edit; end

  # Responds to `POST /identities`
  # Responds to `POST /identities.json`
  def create
    @identity = Identity.new(identity_params)
    respond_to do |format|
      if @identity.save
        format.html { redirect_to @identity, notice: "Identity was successfully created." }
        format.json { render :show, status: :created, location: @identity }
      else
        format.html { render :new }
        format.json { render json: @identity.errors, status: :unprocessable_entity }
      end
    end
  end

  # Responds to `PATCH/PUT /identities/1`
  # Responds to `PATCH/PUT /identities/1.json`
  def update
    respond_to do |format|
      if @identity.update(identity_params)
        format.html { redirect_to @identity, notice: "Identity was successfully updated." }
        format.json { render :show, status: :ok, location: @identity }
      else
        format.html { render :edit }
        format.json { render json: @identity.errors, status: :unprocessable_entity }
      end
    end
  end

  # Responds to `DELETE /identities/1`
  # Responds to `DELETE /identities/1.json`
  def destroy
    @identity.destroy
    respond_to do |format|
      format.html { redirect_to identities_url, notice: "Identity was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_identity
    @identity = Identity.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def identity_params
    params.fetch(:identity, {})
  end
end
