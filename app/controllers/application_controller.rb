class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :null_session

  helper_method :current_user, :logged_in?

  include CanCan::ControllerAdditions

  rescue_from ActionController::InvalidCrossOriginRequest, with: :render_400
  rescue_from StandardError, with: :error_occurred
  rescue_from ActionView::MissingTemplate do |exception|
    render json: {}, status: :unprocessable_entity
  end

  after_action :store_location

  def render_400
    self.response_body = nil
    render(nothing: true, status: 400)
  end

  def store_location
    return unless request.get?
    if (request.path != '/login' &&
        request.path != '/logout' &&
        !request.xhr?) # don't store ajax calls
      session[:previous_url] = request.fullpath
    end
    if (request.path == '/welcome/deposit_login_modal')
      session[:previous_url] = '/datasets/new'
    end
  end

  def redirect_path
    session[:previous_url] || main_app.root_url
  end

  protected
  
  def error_occurred(exception)

    return if exception.class == ActionController::InvalidCrossOriginRequest

    if exception.class == CanCan::AccessDenied
      if exception.action == :create
        if current_user && current_user.role == 'no_deposit'
          redirect_to redirect_path, alert: "ACCOUNT NOT ELIGIBLE TO DEPOSIT DATA.<br/>Faculty, staff, and graduate students are eligible to deposit data in Illinois Data Bank.<br/>Please <a href='/help'>contact the Research Data Service</a> if this determination is in error, or if you have any questions."
        else
          redirect_to '/welcome/deposit_login_modal'
        end
      else
        respond_to do |format|
          format.html { redirect_to redirect_path,
                                    alert: "You are not authorized to access the requested resource.",
                                    status: 403}
          format.json { render nothing: true, status: 403 }
          format.xml { render xml: {error: "unauthorized"}.to_xml, status: 403 }
        end
      end

    elsif exception.class == ActiveRecord::RecordNotFound
      respond_to do |format|
        format.html { render ('errors/error404'), status: 404}
        format.json { render nothing: true, status: 404 }
        format.all { render ('errors/error404'), status: 404}
      end

    else
      exception_string = "*** Standard Error caught in application_controller.rb on #{IDB_CONFIG[:root_url_text]} ***\nclass: #{exception.class}\nmessage: #{exception.message}\n"
      exception_string << Time.now.utc.iso8601

      exception_string << "\nstack:\n"
      exception.backtrace.each do |line|
        exception_string << line
        exception_string << "\n"
      end

      Rails.logger.warn(exception_string)

      if current_user
        exception_string << "\nCurrent User: #{current_user.name} | #{current_user.email}"
      end

      notification = DatabankMailer.error(exception_string)
      notification.deliver_now
      respond_to do |format|
        format.html { render ('errors/error500'), status: 500}
        format.json { render nothing: true, status: 500 }
        format.xml { render xml: {status: 500}.to_xml}
      end

    end

  end

  def record_not_found(exception)

    Rails.logger.warn exception

    redirect_to redirect_path, :alert => "An error occurred and has been logged for review by Research Data Service Staff."

  end

  private

  def current_user
    begin
      if session[:user_id]
        @current_user = User::Shibboleth.find(session[:user_id]) || User::Identity.find(session[:user_id])
      end
    rescue ActiveRecord::RecordNotFound
      session[:user_id] = nil
    end
  end

  def set_current_user(user)
    @current_user = user
    session[:current_user_id] = user.id
  end

  def unset_current_user
    @current_user = nil
    session[:current_user_id] = nil
  end

  def logged_in?
    current_user.present?
  end

  def require_logged_in
    unless logged_in?
      session[:login_return_uri] = request.env['REQUEST_URI']
      redirect_to(login_path)
    end
  end

end
