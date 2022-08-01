class WelcomeController < ApplicationController
  def index
    active_featured_researchers = FeaturedResearcher.where(is_active: true)
    if active_featured_researchers.count.positive?
      @featured_researcher = active_featured_researchers.order(Arel.sql("RANDOM()")).first
    end
  end

  def contact
    @dataset = Dataset.find_by(key: params["key"]) if params.has_key?("key")
  end

  def contact_mail
    if params.has_key?("nobots")
      # ignore the spam
    # elsif verify_recaptcha(message: "MESSAGE NOT SENT: reCAPTCHA verification required")
    #   begin
    #     help_request = DatabankMailer.contact_help(params)
    #     help_request.deliver_now
    #   rescue Net::SMTPSyntaxError => e
    #     if e.message != "501 5.5.2 RCPT TO syntax error" # these are consistently spam
    #       Rails.logger.warn(e.message)
    #       Rails.logger.warn("could not deliver contact mail #{params}")
    #     end
    #   end
    #   redirect_to "/contact", notice: "Your email has been sent to the Research Data Service Team. "
    else
      query_array=["help-name=#{params['help-name']}",
                  "help-email=#{params['help-email']}",
                  "help-topic=#{params['help-topic']}",
                  "help-message=#{params['help-message']}"]
      query_string = query_array.join("&")
      redirect_to "/contact?#{query_string}"
    end
  end

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

  def on_failed_registration; end

  def update_read_only_message
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

  def help_transition_admin
    help = ["Help", Databank::HelpTransitionState::HELP]
    guide = ["Guides", Databank::HelpTransitionState::GUIDE]
    both = ["Both", Databank::HelpTransitionState::BOTH]
    @possible_states = [help, guide, both]
  end

  def update_help_transition
    if params.has_key?("state") && params["state"] != Application.help_transition_state
      File.open(IDB_CONFIG[:help_transition_filepath], "w") { |file| file.write(params["state"]) }
      Application.help_transition_state = params["state"]
    end
    redirect_to action: "help_transition_admin"
  end

  def robots
    # Don't forget to delete /public/robots.txt
    respond_to :text
  end

end
