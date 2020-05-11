# This file is used by Rack-based servers to start the application.
require 'tus/server'

require ::File.expand_path('../config/environment', __FILE__)

map "/files" do
  run Tus::Server
end
run Rails.application
