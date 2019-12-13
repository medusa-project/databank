class WelcomeController < ApplicationController
  def index
    active_featured_researchers = FeaturedResearcher.where(is_active: true)
    if active_featured_researchers.count > 0
      @featured_researcher = active_featured_researchers.order(Arel.sql("RANDOM()")).first
    end
  end

  def check_token
    if params.has_key?('token')

      identified_tokens = Token.where("identifier = ? AND expires > ?", params['token'], DateTime.now)

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
      if params.has_key?(:msg_middle) && Datafile.update_read_only_message(params[:msg_middle])
        format.html {redirect_to @datafile, notice: 'Datafile was successfully updated.'}
        format.json {render :show, status: :ok, location: @datafile}
      elsif Datafile.remove_read_only_message

      else
        format.html {render :index}
        format.json {render json: @datafile.errors, status: :unprocessable_entity}
      end
    end
  end

  def robots
    # Don't forget to delete /public/robots.txt
    respond_to :text
  end

end
