# frozen_string_literal: true

##
# Invitee model
# This model is used to store the invitees
# Invitees are the users who are invited to use the Identity Omniauth provider.

class Invitee < ApplicationRecord
  validates :email, presence: true, uniqueness: true
  before_destroy :destroy_identity
  before_destroy :destroy_user

  ##
  # group
  # This instance method is used to return the group of the invitee
  # @return [String] the group of the invitee
  # @note the group is always "reviewer", but additional logic could be added, and value is changed in object for tests.
  def group
    "reviewer"
  end

  ##
  # destroy_identity
  # This instance method is used to destroy the identity associated with this invitee
  def destroy_identity
    identity = Identity.find_by(email: email)
    identity&.destroy!
  end

  ##
  # destroy_user
  # This instance method is used to destroy the user associated with this invitee
  def destroy_user
    user = User::Identity.find_by(email: email)
    user&.destroy!
  end
end
