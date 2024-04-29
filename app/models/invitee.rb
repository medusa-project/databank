# frozen_string_literal: true

##
# Represents an invitee
# Invitees are the users who are invited to use the Identity Omniauth provider.
#
# == Attributes
#
# * +email+ - (String) - the email of the invitee
# * +role+ - (String) - the role of the invitee
# * +expires_at+ - (DateTime) - the expiration date of the invitee

class Invitee < ApplicationRecord
  validates :email, presence: true, uniqueness: true
  before_destroy :destroy_identity
  before_destroy :destroy_user

  ##
  # @return [String] the group of the invitee
  # @note the group is always "reviewer", but additional logic could be added, and value is changed in object for tests.
  def group
    "reviewer"
  end

  ##
  # destroys the identity associated with this invitee
  def destroy_identity
    identity = Identity.find_by(email: email)
    identity&.destroy!
  end

  ##
  # destroys the user associated with this invitee
  def destroy_user
    user = User::Identity.find_by(email: email)
    user&.destroy!
  end
end
