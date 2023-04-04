require 'rake'
require "socketlabs-injectionapi"

include SocketLabs::InjectionApi
include SocketLabs::InjectionApi::Message

namespace :smtp do

  desc 'send a test email'
  task :send_test => :environment do

    message = BasicMessage.new

    message.subject = "Sending A Basic Message"
    message.html_body = "<html>This is the Html Body of my message.</html>"
    message.plain_text_body = "This is the Plain Text Body of my message."

    message.from_email_address = EmailAddress.new("databank@library.illinois.edu")

    # A basic message supports up to 50 recipients
    # and supports several different ways to add recipients

    # Add a To address by passing the email address
    message.to_email_address.push("srobbins@illinois.edu")
    message.to_email_address.push(EmailAddress.new("mfall3@illinois.edu", "Colleen Fallaw"))

    # // Adding CC Recipients
    # message.add_cc_email_address("recipient3@example.com")
    # message.add_cc_email_address("recipient4@example.com", "Recipient #4")

    # Adding Bcc Recipients
    # message.add_bcc_email_address(EmailAddress.new("recipient5@example.com"))
    # message.add_bcc_email_address(EmailAddress.new("recipient6@example.com", "Recipient #6"))

    # Your SocketLabs ServerId and Injection API key
    client = SocketLabsClient.new(IDB_CONFIG[:smtp][:server_id], IDB_CONFIG[:smtp][:api_key])

    response = client.send(message)
    Rails.logger.warn(response)
  end

end