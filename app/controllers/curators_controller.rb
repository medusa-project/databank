# frozen_string_literal: true
# convenience methods for managing curators, a filter of user_ability records

class CuratorsController < ApplicationController
  before_action :set_user_ability, only: [:show, :edit, :update, :destroy]

  # Responds to `GET /curators`
  def index
    config_admins = IDB_CONFIG[:admin][:netids].split(",").map {|x| x.strip || x }
    @config_admin_uids = config_admins.map {|x| x + "@illinois.edu" }
    @curators = User.curators
    @curator_ability_user_not_found = UserAbility.curators.where.not(user_uid: @curators.pluck(:uid))
  end

  # Responds to `GET /curators/1`
  def show; end

  # Responds to `GET /curators/new`
  def new
    @user_ability = UserAbility.new
  end

  # Responds to `GET /curators/1/edit`
  def edit; end

  # Responds to `POST /curators`
  def create
    @user_ability = UserAbility.new(user_ability_params)

    if @user_ability.save
      redirect_to "/curators", notice: 'Curator was successfully added.'
    else
      render :new
    end
  end

  # Responds to `PATCH/PUT /curators/1`
  def update
    if @user_ability.update(user_ability_params)
      redirect_to "/curators", notice: 'Curator was successfully updated.'
    else
      render :edit
    end
  end

  # Responds to `DELETE /curators/1`
  def destroy
    @user_ability.destroy
    redirect_to "/curators", notice: 'Curator was successfully removed.'
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
