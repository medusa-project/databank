# frozen_string_literal: true

class WelcomeController < ApplicationController
  # Responds to `GET /`
  def index
    active_featured_researchers = FeaturedResearcher.where(is_active: true)
    if active_featured_researchers.count.positive?
      @featured_researcher = active_featured_researchers.order(Arel.sql("RANDOM()")).first
    end
    respond_to do |format|
      format.html
      format.json {render json: @featured_researcher}
      format.xml {render xml: Robot.blank_stare_xml}
    end
  end

  def admin; end
  # Responds to `GET /contact`
  def contact
    @dataset = Dataset.find_by(key: params["key"]) if params.has_key?("key")
    @title = "Contact"
  end

  # Responds to `GET /check_token`
  def check_token
    if params.has_key?("token")

      identified_tokens = Token.where(identifier: params["token"])

      if identified_tokens.count.positive?
        render json: {'isValid': true, 'token': params["token"]}
      else
        render json: {'isValid': false, 'error': "current token not found"}
      end


    else
      render json: {'isValid': false, 'error': "no token provided"}
    end
  end

  # Responds to 'POST /clear_cache'
  def clear_cache
    authorize! :clear_cache, :welcome
    require 'rake'
    Rails.application.load_tasks
    Rake::Task["databank:rails_cache:clear"].reenable
    Rake::Task["databank:rails_cache:clear"].invoke
    # redirect to admin page with notice
    respond_to do |format|
      format.html {redirect_to "/admin", notice: "Rails cache cleared successfully."}
      format.json {render json: {}, status: :ok}
    end
  end

  # Responds to `GET /on_failed_registration`
  def on_failed_registration; end

  # Responds to `POST /update_read_only_message`
  def update_read_only_message
    authorize! :update_read_only_message, :welcome
    respond_to do |format|
      if params.has_key?("msg_middle") &&
          SystemMessage.update_read_only_message(params["msg_middle"])
        format.html {redirect_to "/", notice: "Message was successfully updated."}
        format.json {render :index, status: :ok}
      elsif SystemMessage.remove_read_only_message
        format.html {redirect_to "/", notice: "Message was successfully removed."}
        format.json {render :index, status: :ok}
      else
        format.html {render :index, notice: "unexpected error"}
        format.json {render json: {}, status: :unprocessable_entity}
      end
    end
  end

  # Responds to `GET /robots`
  def robots
    # Don't forget to delete /public/robots.txt
    respond_to :text
  end

  # Responds to `POST /ensure_local_buckets`
  # used to monitor development and testing environment setup
  def ensure_local_buckets
    @local_buckets_ensured = StorageManager.instance.ensure_local_buckets
  end

end
