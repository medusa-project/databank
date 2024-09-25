# frozen_string_literal: true

# Token
# ---------------
# Represents a token for use by the file upload API
#
# == Attributes
#
# * +identifier+ - the token
# * +dataset_key+ - the key of the dataset the token is associated with
# * +expires+ - the time the token expires

require "securerandom"

class Token < ApplicationRecord
  ##
  # @return [String] an authorization token for use by the file upload API
  def self.generate_auth_token
    SecureRandom.uuid.delete("-")
  end
end
