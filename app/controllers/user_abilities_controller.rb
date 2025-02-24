# frozen_string_literal: true

class UserAbilitiesController < ApplicationController
  load_and_authorize_resource
  before_action :set_user_ability, only: [:show, :edit, :update, :destroy]

  # Responds to `GET /user_abilities`
  # Responds to `GET /user_abilities.json`
  def index
    @user_abilities = UserAbility.all
  end

  # Responds to `GET /user_abilities/1`
  # Responds to `GET /user_abilities/1.json`
  def show; end

  # Responds to `GET /user_abilities/new`
  def new
    @user_ability = UserAbility.new
  end

  # Responds to `GET /user_abilities/1/edit`
  def edit; end

  # Responds to `POST /user_abilities`
  # Responds to `POST /user_abilities.json`
  def create
    @user_ability = UserAbility.new(user_ability_params)
    respond_to do |format|
      if @user_ability.save
        if @user_ability.deposit_exception?
          redirect_to "/deposit_exceptions", notice: 'Deposit exception was successfully created.'
          return
        end
        if @user_ability.curator?
          redirect_to "/curators", notice: 'Curator was successfully added.'
          return
        end
        format.html { redirect_to @user_ability, notice: 'User ability was successfully created.' }
        format.json { render :show, status: :created, location: @user_ability }
      else
        format.html { render :new }
        format.json { render json: @user_ability.errors, status: :unprocessable_entity }
      end
    end
  end

  # Responds to `PATCH/PUT /user_abilities/1`
  # Responds to `PATCH/PUT /user_abilities/1.json`
  def update
    respond_to do |format|
      if @user_ability.update(user_ability_params)
        if @user_ability.deposit_exception?
          redirect_to "/deposit_exceptions", notice: 'Deposit exception was successfully updated.'
          return
        end
        if @user_ability.curator?
          redirect_to "/curators", notice: 'Curator was successfully updated.'
          return
        end
        format.html { redirect_to @user_ability, notice: 'User ability was successfully updated.' }
        format.json { render :show, status: :ok, location: @user_ability }
      else
        format.html { render :edit }
        format.json { render json: @user_ability.errors, status: :unprocessable_entity }
      end
    end
  end

  # Responds to `DELETE /user_abilities/1`
  # Responds to `DELETE /user_abilities/1.json`
  def destroy
    @user_ability.destroy
    if @user_ability.deposit_exception?
      redirect_to "/deposit_exceptions", notice: 'Deposit exception was successfully destroyed.'
      return
    end
    if @user_ability.curator?
      redirect_to "/curators", notice: 'Curator was successfully removed.'
      return
    end
    respond_to do |format|
      format.html { redirect_to user_abilities_url, notice: 'User ability was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
  # Use callbacks to share common setup or constraints between actions.
  def set_user_ability
    @user_ability = UserAbility.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def user_ability_params
    params.require(:user_ability).permit(:user_provider, :user_uid, :resource_type, :resource_id, :ability)
  end
end
