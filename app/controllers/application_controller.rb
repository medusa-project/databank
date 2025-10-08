# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :null_session

  helper_method :current_user, :logged_in?

  include CanCan::ControllerAdditions

  rescue_from ActionController::InvalidCrossOriginRequest, with: :render_400
  rescue_from StandardError, with: :error_occurred
  rescue_from ActionView::MissingTemplate do |_exception|
    render json: {}, status: :unprocessable_entity
  end

  after_action :store_location

  def render_400
    self.response_body = nil
    render(nothing: true, status: :bad_request)
  end

  def store_location
    return unless request.get?

    if request.path != "/login" &&
      request.path != "/logout" &&
      !request.xhr? # don't store ajax calls
      session[:previous_url] = request.fullpath
    end
    session[:previous_url] = "/datasets/new" if request.path == "/welcome/deposit_login_modal"
  end

  def redirect_path
    session[:previous_url] || IDB_CONFIG[:root_url_text]
  end

  protected

  def error_occurred(exception)
    if exception.instance_of?(RSolr::Error::Http)
      respond_to do |format|
        format.html { redirect_to redirect_path, status: :bad_request }
        format.json { render nothing: true, status: :bad_request }
        format.xml { render xml: {error: "bad request"}.to_xml, status: :bad_request }
      end
    elsif exception.instance_of?(ActionController::InvalidCrossOriginRequest)
      respond_to do |format|
        format.html { redirect_to IDB_CONFIG[:root_url_text], status: :unauthorized }
        format.json { render nothing: true, status: :unauthorized }
        format.xml { render xml: {error: "unauthorized"}.to_xml, status: :unauthorized }
      end
    elsif exception.instance_of?(CanCan::AccessDenied)
      Rails.logger.warn("CanCan::AccessDenied: #{exception.action}") if Rails.env.test?
    
      if exception.action == :create || exception.action == :new
        if current_user && current_user.role == "no_deposit"
          redirect_to redirect_path,
                      alert: "ACCOUNT NOT ELIGIBLE TO DEPOSIT DATA.<br/>Faculty, staff, and graduate students are eligible to deposit data in Illinois Data Bank.<br/>Please <a href='/help'>contact the Research Data Service</a> if this determination is in error, or if you have any questions."
        else
          #Rails.logger.warn("redirecting to /welcome/deposit_login_modal") if Rails.env.test?
          redirect_to "/welcome/deposit_login_modal"
        end
      else
        respond_to do |format|
          format.html {
            redirect_to redirect_path,
                        alert:  "You are not authorized to access the requested resource.",
                        status: :forbidden
          }
          format.json { render nothing: true, status: :forbidden }
          format.xml { render xml: {error: "unauthorized"}.to_xml, status: :forbidden }
        end
      end

    elsif exception.instance_of?(ActiveRecord::RecordNotFound)
      respond_to do |format|
        format.html { render "errors/error404", status: :not_found }
        format.json { render nothing: true, status: :not_found }
        format.all { render "errors/error404", status: :not_found }
      end

    else
      exception_string_array = []
      exception_string_array << "*** Standard Error caught in application_controller.rb on #{IDB_CONFIG[:root_url_text]} ***\nclass: #{exception.class}\nmessage: #{exception.message}\n"
      exception_string_array << Time.now.utc.iso8601

      exception_string_array << "\nstack:\n"
      exception.backtrace.each do |line|
        exception_string_array << line
        exception_string_array << "\n"
      end
      if current_user
        exception_string_array << "\nCurrent User: "
        exception_string_array << (current_user.name || current_user.email)
      end
      exception_string = exception_string_array.join("")
      Rails.logger.warn(exception_string)

      notification = DatabankMailer.error(exception_string)
      notification.deliver_now
      respond_to do |format|
        format.html { render "errors/error500", status: :internal_server_error }
        format.json { render nothing: true, status: :internal_server_error }
        format.xml { render xml: {status: 500}.to_xml }
      end
    end
  end

  def record_not_found(exception)
    Rails.logger.warn exception

    redirect_to redirect_path,
                alert: "An error occurred and has been logged for review by Research Data Service Staff."
  end

  private

  # @return [User] the current user
  def current_user
    if session[:user_id]
      @current_user = User.find(session[:user_id])
    end
  rescue ActiveRecord::RecordNotFound
    session[:user_id] = nil
  end

  ##
  # sets the current user
  # @param [User] user
  # @return [User] the current user
  def set_current_user(user)
    @current_user = user
    session[:current_user_id] = user.id
  end

  ##
  # unsets the current user
  # @return [nil]
  def unset_current_user
    @current_user = nil
    session[:current_user_id] = nil
  end

  ##
  # checks if a user is logged in
  # @return [Boolean] true if a user is logged in
  def logged_in?
    current_user.present?
  end

  ##
  # requires a user to be logged in
  # @return [nil]
  # @raise [ActionController::InvalidCrossOriginRequest] if the request is not from the same origin
  def require_logged_in
    unless logged_in?
      session[:login_return_uri] = request.env["REQUEST_URI"]
      redirect_to(login_path)
    end
  end
end
