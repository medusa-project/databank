if Application.server_envs.include?(Rails.env)
  Application.ldap = Net::LDAP.new :host => Rails.application.credentials[:ldap][:host],
                                   :port => 389,
                                   :auth => {
                                       :method => :simple,
                                       :username => Rails.application.credentials[:ldap][:username],
                                       :password => Rails.application.credentials[:ldap][:password]
                                   },
                                   :encryption => {
                                       :method => :start_tls,
                                       :tls_options => OpenSSL::SSL::SSLContext::DEFAULT_PARAMS,
                                   }
  Application.ldap.bind
end
