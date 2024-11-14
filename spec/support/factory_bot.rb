# spec/support/factory_bot.rb
require 'rails_helper'

RSpec.configure do |config|
    config.include FactoryBot::Syntax::Methods
end