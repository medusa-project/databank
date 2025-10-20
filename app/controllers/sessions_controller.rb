# frozen_string_literal: true

class SessionsController < ApplicationController

  skip_before_action :verify_authenticity_token

  # Responds to `GET /login`
  def new
    unless Rails.env.test? || Rails.env.development?
      session[:login_return_referer] = request.env['HTTP_REFERER']
      redirect_to(shibboleth_login_path(Databank::Application.shibboleth_host))
      return
    end
  end

  # Responds to `POST /auth/:provider/callback`
  def create
    auth = request.env["omniauth.auth"]

    unless auth[:provider] && ['shibboleth', 'developer'].include?(auth[:provider])
      unauthorized
      return
    end

    if auth[:provider] == 'developer' && !(Rails.env.test? || Rails.env.development?)
      unauthorized
      return
    end

    user = User.from_omniauth(auth)

    if user&.id
      session[:user_id] = user.id
      if user.role == 'no_deposit'
        redirect_to root_url, notice: "ACCOUNT NOT ELIGABLE TO DEPOSIT DATA.<br/>Faculty, staff, and graduate students are eligable to deposit data in Illinois Data Bank.<br/>Please <a href='/help'>contact the Research Data Service</a> if this determination is in error, or if you have any questions."
      else
        redirect_to return_url
      end
    else
      redirect_to root_url
    end

  end

  # Responds to `GET /logout`
  def destroy
    session[:user_id] = nil
    redirect_to root_url
  end

  # Responds to `GET /auth/failure`
  def unauthorized
    redirect_to root_url, notice: "The supplied credentials could not be authenciated."
  end

  # Responds to `POST /role_switch`
  def role_switch
    new_role = params['role']
    if ['depositor', 'guest', 'no_deposit'].include?(new_role)
      new_role_text = "new role"
      case new_role
      when 'depositor'
        current_user.update_attribute(:role, Databank::UserRole::DEPOSITOR)
        new_role_text = "depositor"
      when 'guest'
        current_user.update_attribute(:role, Databank::UserRole::GUEST)
        new_role_text = "guest"
      when 'no_deposit'
        current_user.update_attribute(:role, Databank::UserRole::NO_DEPOSIT)
        new_role_text = "undergrad, or other authenticated but not authorized agent"
      end
      redirect_to root_url, notice: "Successfully switched role to #{new_role_text}."
    else
      redirect_to root_url, notice: "Unable to switch roles."
    end
  end

  protected

  def return_url
    Rails.logger.warn("return_url DEBUG: #{session[:login_return_uri]}, #{session[:login_return_referer]}, #{root_path}")
    session[:login_return_uri] || session[:login_return_referer] || root_path
  end


  def shibboleth_login_path(host)
    "/Shibboleth.sso/Login?target=https://#{host}/auth/shibboleth/callback"
  end

end