class SessionsController < ApplicationController

  skip_before_action :verify_authenticity_token

  def new
    session[:login_return_referer] = request.env['HTTP_REFERER']
    redirect_to(shibboleth_login_path(Databank::Application.shibboleth_host))
  end

  def create

    auth = request.env["omniauth.auth"]

    if auth[:provider] && auth[:provider] == 'shibboleth'
      user = User::Shibboleth.from_omniauth(auth)
    elsif auth[:provider] && auth[:provider] == 'identity'
      user = User::Identity.from_omniauth(auth)
    else
      unauthorized
    end

    if user&.id
      session[:user_id] = user.id
      if user.provider == 'identity' && user.role == Databank::UserRole::NETWORK_REVIEWER
        redirect_to '/data_curation_network'
      elsif user.role == 'no_deposit'
        redirect_to root_url, notice: "ACCOUNT NOT ELIGABLE TO DEPOSIT DATA.<br/>Faculty, staff, and graduate students are eligable to deposit data in Illinois Data Bank.<br/>Please <a href='/help'>contact the Research Data Service</a> if this determination is in error, or if you have any questions."
      else
        redirect_to return_url
      end
    elsif session[:previous_url] == '/data_curation_network/register'
      redirect_to '/data_curation_network/after_registration'
    else
      redirect_to root_url
    end

  end

  def destroy
    session[:user_id] = nil
    redirect_to root_url
  end

  def unauthorized
    redirect_to root_url, notice: "The supplied credentials could not be authenciated."
  end

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
    session[:login_return_uri] || session[:login_return_referer] || root_path
  end


  def shibboleth_login_path(host)
    "/Shibboleth.sso/Login?target=https://#{host}/auth/shibboleth/callback"
  end

end
