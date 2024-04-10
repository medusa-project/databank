# frozen_string_literal: true

##
# This module supports the uploading of datafiles into draft datasets via the API.
# It is included in the Dataset model.
module Dataset::Uploadable
  extend ActiveSupport::Concern

  ##
  # @return [String] the token for use by the file upload API
  # @note it returns the first token if there is only one token
  # @note it destroys all tokens if there are multiple tokens and creates a new token
  def current_token
    tokens = Token.where(dataset_key: self.key)
    return nil if tokens.count.zero?

    return tokens.first if tokens.count == 1

    tokens.destroy_all
    new_token
  end

  ##
  # @return [String] the token for use by the file upload API
  # @note it destroys all tokens and creates a new token
  def new_token
    Token.where(dataset_key: key).destroy_all
    Token.create(dataset_key: key, identifier: Token.generate_auth_token)
  end

end
