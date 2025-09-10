# frozen_string_literal: true
# convenience methods for managing deposit exceptions, a filter of user_ability records

class DepositExceptionsController < ApplicationController
  before_action :set_user_ability, only: [:show, :edit, :update, :destroy]

  # Responds to `GET /deposit_exceptions`
  # Responds to `GET /deposit_exceptions.json`
  def index
    @user_abilities = UserAbility.where(resource_type: 'Dataset', ability: 'create', resource_id: nil)
  end

  # Responds to `GET /deposit_exceptions/1`
  # Responds to `GET /deposit_exceptions/1.json`
  def show; end

  # Responds to `GET /deposit_exceptions/new`
  def new
    @user_ability = UserAbility.new
  end

  # Responds to `GET /deposit_exceptions/1/edit`
  def edit; end

  # Responds to `POST /deposit_exceptions`
  # Responds to `POST /deposit_exceptions.json`
  def create
    @user_ability = UserAbility.new(user_ability_params)

    respond_to do |format|
      if @user_ability.save
        format.html { redirect_to "/deposit_exceptions", notice: 'Deposit exception was successfully created.' }
        format.json { render :show, status: :created, location: @user_ability }
      else
        format.html { render :new }
        format.json { render json: @user_ability.errors, status: :unprocessable_entity }
      end
    end
  end

  # Responds to `PATCH/PUT /deposit_exceptions/1`
  # Responds to `PATCH/PUT /deposit_exceptions/1.json`
  def update
    respond_to do |format|
      if @user_ability.update(user_ability_params)
        format.html { redirect_to "/deposit_exceptions", notice: 'Deposit exception was successfully updated.' }
        format.json { render :show, status: :ok, location: @user_ability }
      else
        format.html { render :edit }
        format.json { render json: @user_ability.errors, status: :unprocessable_entity }
      end
    end
  end

  # Responds to `DELETE /deposit_exceptions/1`
  # Responds to `DELETE /deposit_exceptions/1.json`
  def destroy
    @user_ability.destroy
    respond_to do |format|
      format.html { redirect_to "/deposit_exceptions", notice: 'Deposit exception was successfully destroyed.' }
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
