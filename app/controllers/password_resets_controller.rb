# frozen_string_literal: true
# Password Resets Controller interacts with Identity model to reset password

class PasswordResetsController < ApplicationController
  before_action :set_identity, only: [:edit, :update]
  before_action :valid_identity, only: [:edit, :update]
  before_action :check_expiration, only: [:edit, :update]

  # Forgot password form
  # Responds to `GET /password_resets/new`
  def new; end

  # Sends password reset email if an identity is found for the email
  # Responds to `POST /password_resets`
  def create
    @identity = Identity.find_by(email: params[:password_reset][:email].downcase)
    if @identity
      @identity.create_reset_digest
      @identity.send_password_reset_email
      if @identity.role == Databank::UserRole::NETWORK_REVIEWER
        redirect_to "/data_curation_network", notice: "Email sent with password reset instructions"
      else
        redirect_to root_url, notice: "Email sent with password reset instructions"
      end

    else
      render "new", alert: "Email address not found"
    end
  end

  # Password reset form
  # Responds to `GET /password_resets/:id/edit`
  def edit; end

  # Updates the password, which is in identity
  # Responds to `PATCH /password_resets/:id`
  def update
    if params[:identity][:password].empty?
      @identity.errors.add(:password, "can't be empty")
      render "edit"
    elsif @identity.update(user_params)
      # assumes data curation network -- when there are other use cases add code branches here
      redirect_to "/data_curation_network", notice: "Password has been reset. Log in here."
    else
      render "edit"
    end
  end

  private

  def identity_params
    params.require(:identity).permit(:password, :password_confirmation)
  end

  def set_identity
    @identity = Identity.find_by(email: params[:email])
  end

  # Confirms a valid user.
  def valid_identity
    unless @identity&.activated? &&
      @identity&.authenticated?(:reset, params[:id])
      redirect_to root_url
    end
  end

  # Checks expiration of reset token.
  def check_expiration
    return unless @identity.password_reset_expired?

    redirect_to new_password_reset_url, alert: "Password reset has expired."
  end
end
