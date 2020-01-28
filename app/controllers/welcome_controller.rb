class WelcomeController < ApplicationController
  def index
    active_featured_researchers = FeaturedResearcher.where(is_active: true)
    if active_featured_researchers.count > 0
      @featured_researcher = active_featured_researchers.order(Arel.sql("RANDOM()")).first
    end
  end

  def check_token
    if params.has_key?('token')

      identified_tokens = Token.where(identifier: params['token'])

      if identified_tokens.count > 0
        render :json => {'isValid': true, 'token': params['token']}
      else
        render :json => {'isValid': false, 'error': 'current token not found'}
      end


    else
      render :json => {'isValid': false, 'error': 'no token provided'}
    end
  end

  def on_failed_registration; end

  def update_read_only_message

    respond_to do |format|
      if params.has_key?('msg_middle') && Datafile.update_read_only_message(params['msg_middle'])
        Application.read_only_msg_middle = params['msg_middle']
        Application.read_only_message = Datafile.read_only_message
        format.html {redirect_to "/", notice: "Message was successfully updated."}
        format.json {render :index, status: :ok}
      elsif Datafile.remove_read_only_message
        Application.read_only_msg_middle = nil
        Application.read_only_message = Datafile.read_only_message
        format.html {redirect_to "/", notice: "Message was successfully removed."}
        format.json {render :index, status: :ok}
      else
        format.html {render :index, notice: "unexpected error"}
        format.json {render json: {}, status: :unprocessable_entity}
      end
    end
  end

  def robots
    # Don't forget to delete /public/robots.txt
    respond_to :text
  end

end
