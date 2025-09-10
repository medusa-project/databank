# frozen_string_literal: true
# convenience methods for managing curators, a filter of user_ability records

class CuratorsController < ApplicationController
  before_action :set_user_ability, only: [:show, :edit, :update, :destroy]

  # Responds to `GET /curators`
  # Responds to `GET /curators.json`
  def index
    config_admins = IDB_CONFIG[:admin][:netids].split(",").map {|x| x.strip || x }
    @config_admin_uids = config_admins.map {|x| x + "@illinois.edu" }
    @curators = User.curators
    @curator_ability_user_not_found = UserAbility.curators.where.not(user_uid: @curators.pluck(:uid))
  end

  # Responds to `GET /curators/1`
  # Responds to `GET /curators/1.json`
  def show; end

  # Responds to `GET /curators/new`
  def new
    @user_ability = UserAbility.new
  end

  # Responds to `GET /curators/1/edit`
  def edit; end

  # Responds to `POST /curators`
  # Responds to `POST /curators.json`
  def create
    @user_ability = UserAbility.new(user_ability_params)

    respond_to do |format|
      if @user_ability.save
        format.html { redirect_to "/curators", notice: 'Curator was successfully added.' }
        format.json { render :show, status: :created, location: @user_ability }
      else
        format.html { render :new }
        format.json { render json: @user_ability.errors, status: :unprocessable_entity }
      end
    end
  end

  # Responds to `PATCH/PUT /curators/1`
  # Responds to `PATCH/PUT /curators/1.json`
  def update
    respond_to do |format|
      if @user_ability.update(user_ability_params)
        format.html { redirect_to "/curators", notice: 'Curator was successfully updated.' }
        format.json { render :show, status: :ok, location: @user_ability }
      else
        format.html { render :edit }
        format.json { render json: @user_ability.errors, status: :unprocessable_entity }
      end
    end
  end

  # Responds to `DELETE /curators/1`
  # Responds to `DELETE /curators/1.json`
  def destroy
    @user_ability.destroy
    respond_to do |format|
      format.html { redirect_to "/curators", notice: 'Curator was successfully removed.' }
      format.json { head :no_content }
    end
  end

  private
  # Use callbacks to share common setup or constraints between actions.
  def set_user_ability
    @user_ability = UserAbility.find(params[:id])
    @user = User.find_by(provider: @user_ability.user_provider, uid: @user_ability.user_uid)
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def user_ability_params
    params.require(:user_ability).permit(:user_provider, :user_uid, :resource_type, :resource_id, :ability)
  end
end
