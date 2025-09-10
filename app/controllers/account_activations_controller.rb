# frozen_string_literal: true

# This controller is responsible for handling the activation of a user's account.
# It is called when a user clicks on the activation link sent to their email.
# The activation link contains the user's email and an activation token.
# The controller checks if the email and token are valid and if so, activates the user's account.
# The user is then redirected to the home page with a message indicating that their account has been activated.
# If the email and token are invalid, the user is redirected to the home page with a message indicating that the
# activation link is invalid.
# Used as part of the local identity strategy for omniauth https://github.com/omniauth/omniauth-identity

class AccountActivationsController < ApplicationController
  ##
  # Activates the user's account if the email and token are valid.
  # Responds to `GET /account_activations/:id/edit URL`
  def edit
    identity = Identity.find_by(email: params[:email])
    if identity && !identity.activated? && identity.authenticated?(:activation, params[:id])
      identity.update_attribute(:activated,    true)
      identity.update_attribute(:activated_at, Time.zone.now)
      invitee = Invitee.find_by(email: identity.email)
      if invitee&.role == Databank::UserRole::NETWORK_REVIEWER
        redirect_to '/data_curation_network', alert: "Account activated! Log in here."
      else
        redirect_to '/', alert: "Account activated!"
      end
    else
      redirect_to root_url, alert: "Invalid activation link"
    end
  end
end
