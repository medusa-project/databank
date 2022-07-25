# frozen_string_literal: true

class InviteesController < ApplicationController
  before_action :set_invitee, only: %i[show edit update destroy]

  # GET /invitees
  # GET /invitees.json
  def index
    @invitees = Invitee.all
  end

  # GET /invitees/1
  # GET /invitees/1.json
  def show; end

  # GET /invitees/new
  def new
    @invitee = Invitee.new
    @role_arr = Array.new
    @role_arr.push(Databank::UserRole::NETWORK_REVIEWER)
    @role_arr.push(Databank::UserRole::PUBLISHER_REVIEWER)
    @role_arr.push(Databank::UserRole::CREATOR)
  end

  # GET /invitees/1/edit
  def edit
    @role_arr = Array.new
    @role_arr.push(Databank::UserRole::NETWORK_REVIEWER)
    @role_arr.push(Databank::UserRole::PUBLISHER_REVIEWER)
    @role_arr.push(Databank::UserRole::CREATOR)
  end

  # POST /invitees
  # POST /invitees.json
  def create
    @invitee = Invitee.new(invitee_params)

    authorize! :manage, @invitee

    respond_to do |format|
      if @invitee.save
        if @invitee.role == Databank::UserRole::NETWORK_REVIEWER
          format.html { redirect_to "/data_curation_network/accounts", notice: "Invitee was successfully created." }
        else
          format.html { redirect_to @invitee, notice: "Invitee was successfully created." }
        end
        format.json { render :show, status: :created, location: @invitee }
      else
        if @invitee.role == Databank::UserRole::NETWORK_REVIEWER
          format.html { redirect_to "/data_curation_network/accounts", notice: "Error attempting to create invitee." }
        else
          format.html { render :new }
        end
        format.json { render json: @invitee.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /invitees/1
  # PATCH/PUT /invitees/1.json
  def update
    authorize! :manage, @invitee

    respond_to do |format|
      if @invitee.update
        if @invitee.role == Databank::UserRole::NETWORK_REVIEWER
          format.html { redirect_to "/data_curation_network/accounts", notice: "Invitee was successfully updated." }
        else
          format.html { redirect_to @invitee, notice: "Invitee was successfully updated." }
        end
        format.json { render :show, status: :ok, location: @invitee }
      else
        if @invitee.role == Databank::UserRole::NETWORK_REVIEWER
          edit_path = "/data_curation_network/account/#{@invitee_id}/edit"
          format.html { redirect_to(edit_path, notice: "Error attempting to update invitee.") }
        else
          format.html { render :edit }
        end
        format.json { render json: @invitee.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /invitees/1
  # DELETE /invitees/1.json
  def destroy
    authorize! :manage, @invitee
    @invitee.destroy
    respond_to do |format|
      format.html { redirect_to "/data_curation_network/accounts", notice: "Account was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_invitee
    @invitee = Invitee.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def invitee_params
    params.require(:invitee).permit(:email, :group, :role, :expires_at)
  end
end
