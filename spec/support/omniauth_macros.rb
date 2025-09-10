# spec/support/omniauth_macros.rb
module OmniauthMacros
  def mock_auth_hash(user)
    OmniAuth.config.mock_auth[:developer] = OmniAuth::AuthHash.new({
      provider: user.provider,
      uid: user.uid,
      info: {
        email: user.email,
        name: user.name,
        role: user.role
      }
    })
  end

  # for use from controller specs, so request.env
  def sign_in(user)
    mock_auth_hash(user)
    request.env['omniauth.auth'] = OmniAuth.config.mock_auth[:developer]
    session[:user_id] = user.id
  end

  # for use from request specs, so no request.env
  def log_in(user)
    mock_auth_hash(user)
    post '/auth/developer/callback'
    follow_redirect!
  end

end