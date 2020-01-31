class HelpController < ApplicationController
  def index
    if params.has_key?('key')
      @dataset = Dataset.find_by_key(params['key'])
    end
  end

  def help_mail
    if params.has_key?("nobots")
      # ignore the spam
    elsif verify_recaptcha(message: 'MESSAGE NOT SENT: reCAPTCHA verification required', error_callback: :quarantine)
      help_request = DatabankMailer.contact_help(params)
      help_request.deliver_now
      redirect_to '/help', notice: "Your email has been sent to the Research Data Service Team. "
    else
      redirect_to '/help'
    end

  end

end