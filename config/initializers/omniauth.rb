shib_opts = YAML.load_file(File.join(Rails.root, 'config', 'shibboleth.yml'))[Rails.env]

Rails.application.config.middleware.use OmniAuth::Builder do

  if Rails.env.development? || Rails.env.test?
    provider :developer, :fields => [:email, :name, :role], :uid_field => :email

      # host: localhost
      # uid_field: eppn
      # extra_fields:
      #   - eppn
      #   - unscoped-affiliation
      #   - uid
      #   - sn
      #   - nickname
      #   - mail
      #   - givenName
      #   - displayName
      #   - iTrustAffiliation
      #   - uiucEduStudentLevelCode
      # request_type: header
      # info_fields:
      #   name: displayName
      #   email: mail

  else
    provider :shibboleth, shib_opts.symbolize_keys
  end

end

OmniAuth.config.on_failure = Proc.new { |env|
  OmniAuth::FailureEndpoint.new(env).redirect_to_failure
}

Databank::Application.shibboleth_host = shib_opts['host']