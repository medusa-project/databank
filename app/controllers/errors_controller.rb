# frozen_string_literal: true

class ErrorsController < ApplicationController

  # Responds to 'Post /' and matches all routes not otherwise defined in the routes.rb file.
  def error404
    respond_to do |format|
      format.html { render "errors/error404", status: :not_found}
      format.all { render nothing: true, status: :not_found }
    end
  end

  # Renders the error500 page when an internal server error occurs.
  def error500
    respond_to do |format|
      format.html { render "errors/error500", status: :internal_server_error}
      format.all { render nothing: true, status: :internal_server_error }
    end
  end
end
