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

  def sign_in(user)
    mock_auth_hash(user)
    request.env['omniauth.auth'] = OmniAuth.config.mock_auth[:developer]
    session[:user_id] = user.id
  end
end