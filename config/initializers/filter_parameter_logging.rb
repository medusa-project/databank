# Be sure to restart your server when you modify this file.

# Configure sensitive parameters which will be filtered from the log file.
Rails.application.config.filter_parameters += [:password]
Rails.application.config.filter_parameters += [:code, :code_verifier, :access_token, :refresh_token,
                                               :client_secret, :encrypted_credentials, :subject_token]
