# frozen_string_literal: true

##
# ShareCode
# A ShareCode is a unique code that can be used to access a dataset without
# needing to be logged in. ShareCodes are generated automatically when a dataset
# is shared, and can be revoked at any time.
#
# # == Attributes
# * +code+ - the unique code that can be used to access the dataset
# * +dataset_id+ - the id of the dataset the code is associated with

class ShareCode < ApplicationRecord
  belongs_to :dataset
  before_create :set_code

  ##
  # set_code
  # Sets the code attribute to a generated code if it is not already set
  # @return [String] the code, either the existing code or a generated code
  def set_code
    self.code ||= generate_code
  end

  ##
  # generate_code
  # Generates a guaranteed-unique code
  # @return [String] a unique code
  def generate_code
    proposed_code = SecureRandom.urlsafe_base64(32, false)
    loop do
      break unless self.class.find_by(code: proposed_code)

      proposed_code = SecureRandom.urlsafe_base64(32, false)
    end
    proposed_code
  end
end
