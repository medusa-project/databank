# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :null_session

  helper_method :current_user, :logged_in?

  include CanCan::ControllerAdditions

  rescue_from StandardError, with: :error_occurred
  # Guardrail: handled 400-class errors are intentionally not logged by default.
  # Ask before adding any new 400 scenario to loggable/notification paths.
  rescue_from ActionController::InvalidCrossOriginRequest, with: :render_400
  rescue_from ActionController::UnknownFormat, with: :render_406
  rescue_from ActionDispatch::RemoteIp::IpSpoofAttackError, with: :render_400
  rescue_from ActionDispatch::Http::Parameters::ParseError, with: :render_400
  rescue_from Rack::QueryParser::InvalidParameterError, with: :render_400
  rescue_from ActionView::MissingTemplate do |_exception|
    render json: {}, status: :unprocessable_content
  end

  after_action :store_location

  def render_400
    head :bad_request
  end

  def render_406
    head :not_acceptable
  end

  def store_location
    return unless request.get?

    if request.path != "/login" &&
      request.path != "/logout" &&
      !request.xhr? # don't store ajax calls
      session[:previous_url] = request.fullpath
    else
      session[:previous_url] = IDB_CONFIG[:root_url_text]
    end
  end

  def redirect_path
    session[:previous_url] || IDB_CONFIG[:root_url_text]
  end

  protected

  def error_occurred(exception)
    if exception.is_a?(RSolr::Error::Http)
      handle_solr_error
    elsif exact_instance_of?(exception, CanCan::AccessDenied)
      handle_access_denied(exception)
    elsif exact_instance_of?(exception, ActiveRecord::RecordNotFound)
      handle_record_not_found
    else
      handle_unexpected_exception(exception)
    end
  end

  def record_not_found(exception)
    Rails.logger.warn exception

    redirect_to redirect_path,
                alert: "An error occurred and has been logged for review by Research Data Service Staff."
  end

  def exact_instance_of?(exception, klass)
    exception.instance_of?(klass)
  end

  def handle_solr_error
    respond_with_redirect_error(
      redirect_target: redirect_path,
      status: :bad_request,
      xml_error: "bad request"
    )
  end

  def handle_access_denied(exception)
    Rails.logger.warn("CanCan::AccessDenied: #{exception.action} on #{exception.subject}\n#{params.to_yaml}") if Rails.env.test?

    if exception.subject.is_a?(Dataset) && (exception.action == :create || exception.action == :new)
      if current_user && current_user.role == "no_deposit"
        redirect_to redirect_path,
                    alert: "ACCOUNT NOT ELIGIBLE TO DEPOSIT DATA.<br/>Faculty, staff, and graduate students are eligible to deposit data in Illinois Data Bank.<br/>Please <a href='/help'>contact the Research Data Service</a> if this determination is in error, or if you have any questions."
      end
    else
      respond_with_redirect_error(
        redirect_target: redirect_path,
        status: :forbidden,
        xml_error: "unauthorized",
        alert: "You are not authorized to access the requested resource."
      )
    end
  end

  def handle_record_not_found
    respond_with_rendered_error(template: "errors/error404", status: :not_found)
  end

  def handle_unexpected_exception(exception)
    exception_string = build_exception_string(exception)
    Rails.logger.warn(exception_string)

    notification = DatabankMailer.error(exception_string)
    notification.deliver_now

    respond_with_internal_server_error
  end

  def build_exception_string(exception)
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

    exception_string_array.join("")
  end

  def respond_with_redirect_error(redirect_target:, status:, xml_error:, alert: nil)
    respond_to do |format|
      format.html { redirect_to redirect_target, status: status, alert: alert }
      format.json { render nothing: true, status: status }
      format.xml { render xml: {error: xml_error}.to_xml, status: status }
    end
  end

  def respond_with_rendered_error(template:, status:)
    respond_to do |format|
      format.html { render template, status: status }
      format.json { render nothing: true, status: status }
      format.all { render template, status: status }
    end
  end

  def respond_with_internal_server_error
    respond_to do |format|
      format.html { render "errors/error500", status: :internal_server_error }
      format.json { render nothing: true, status: :internal_server_error }
      format.xml { render xml: {status: 500}.to_xml }
    end
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
