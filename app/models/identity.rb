# frozen_string_literal: true

##
# Identity model
# This model is used to support the OmniAuth identity provider,
# which allows users to sign in with a username and password.
# Used to support the Data Curation System in production.
# Used to support development and testing in local environments.

class Identity < OmniAuth::Identity::Models::ActiveRecord
  attr_accessor :activation_token, :reset_token
  before_create :set_invitee
  before_create :create_activation_digest
  after_create :send_activation_email
  before_destroy :destroy_user
  validates :name, presence: true
  validates :email, presence: true, length: {maximum: 255},
            format: {with: VALID_EMAIL_REGEX},
            uniqueness: {case_sensitive: false}
  has_secure_password
  validates :password, presence: true, length: {minimum: 5}
  validate :invited

  ##
  # authenticated?
  # @return [Boolean] true if the given token matches the digest.
  def authenticated?(attribute, token)
    digest = send("#{attribute}_digest")
    return false if digest.nil?

    BCrypt::Password.new(digest).is_password?(token)
  end

  ##
  # digest (class method
  # Returns the hash digest of the given string.
  # @param string [String] the string to be hashed
  # @return [String] the hashed string
  def self.digest(string)
    cost = if ActiveModel::SecurePassword.min_cost
             BCrypt::Engine::MIN_COST
           else
             BCrypt::Engine.cost
           end
    BCrypt::Password.create(string, cost: cost)
  end

  ##
  # new_token (class method)
  # Returns a random token.
  def self.new_token
    SecureRandom.urlsafe_base64
  end

  ##
  # invited
  # This instance method is used to check if the identity has an invitation
  # @return [Boolean] true if the identity has an invitation, false otherwise
  def invited
    set_invitee
    errors.add(:base, "Registered identity must have current invitation.") unless [nil, ""].exclude?(invitee_id)
  end

  ##
  # activation_url
  # This instance method is used to return the activation URL for the identity
  # @return [String] the activation URL
  def activation_url
    "#{IDB_CONFIG[:root_url_text]}/account_activations/#{activation_token}/edit?email=#{CGI.escape(email)}"
  end

  ##
  # password_reset_url
  # This instance method is used to return the password reset URL for the identity
  # @return [String] the password reset URL
  def password_reset_url
    "#{IDB_CONFIG[:root_url_text]}/password_reset/#{reset_token}/edit?email=#{CGI.escape(email)}"
  end

  ##
  # send_activation_email
  # This instance method is used to send the activation email for the identity
  def send_activation_email
    notification = DatabankMailer.account_activation(self)
    notification.deliver_now
  end

  ##
  # send_password_reset_email
  # Sends password reset email.
  def send_password_reset_email
    notification = DatabankMailer.password_reset(self)
    notification.deliver_now
  end

  ##
  # create_activation_digest
  # Creates and assigns the activation token and digest.
  def create_activation_digest
    self.activation_token = Identity.new_token
    self.activation_digest = Identity.digest(activation_token)
  end

  ##
  # create_reset_digest
  # Sets the password reset attributes.
  def create_reset_digest
    reset_token = Identity.new_token
    update_attribute(:reset_digest, Identity.digest(reset_token))
    update_attribute(:reset_sent_at, Time.zone.now)
  end

  ##
  # password_reset_expired?
  # @return [Boolean] true if the password reset has expired, false otherwise
  def password_reset_expired?
    reset_sent_at < 2.hours.ago
  end

  ##
  # create_test_account (class method)
  # This class method is used to create a test account
  def self.create_test_account(name:, email:, role:)
    invitee = Invitee.find_or_create_by(email: email)
    invitee.role = role
    invitee.expires_at = Time.zone.now + 1.years
    invitee.save!
    identity = Identity.find_or_create_by(email: email)
    salt = BCrypt::Engine.generate_salt
    localpass = IDB_CONFIG[:admin][:localpass]
    encrypted_password = BCrypt::Engine.hash_secret(localpass, salt)
    identity.password_digest = encrypted_password
    identity.update(password: localpass, password_confirmation: localpass)
    identity.name = name
    identity.activated = true
    identity.activated_at = Time.zone.now
    identity.save!
  end

  private

  ##
  # downcase_email
  # Converts email to all lower-case.
  def downcase_email
    self.email = email.downcase
  end

  ##
  # destroy_user
  # Destroys the user associated with the identity.
  def destroy_user
    user = User::Identity.find_by(email: email)
    user&.destroy!
  end

  ##
  # set_invitee
  # Sets the invitee for the identity.
  def set_invitee
    @invitee = Invitee.find_by(email: email)
    self.invitee_id = @invitee.id if @invitee && @invitee.expires_at > Time.current
  end
end
