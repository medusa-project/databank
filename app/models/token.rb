# frozen_string_literal: true

require "securerandom"

class Token < ApplicationRecord
  ##
  # @return [String] an authorization token for use by the file upload API
  def self.generate_auth_token
    SecureRandom.uuid.delete("-")
  end
end
