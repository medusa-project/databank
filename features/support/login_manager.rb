require 'singleton'
require 'yaml'

class LoginManager
  include Singleton

  attr_accessor :login_data

  def initialize(args = {})
    login_file = File.join(File.dirname(__FILE__), 'login_data.yml')
    unless File.exists?(login_file)
      raise RuntimeError, "Must specify login information in #{login_file}"
    end
    self.login_data = YAML.load_file(login_file)
  end

  def credentials(type)
    self.login_data[type.to_s]
  end

  def name(type)
    self.credentials(type)['name']
  end

  def email(type)
    self.credentials(type)['auth_key']
  end

  def auth_key(type)
    self.credentials(type)['auth_key']
  end

  def password(type)
    self.credentials(type)['password']
  end

end
