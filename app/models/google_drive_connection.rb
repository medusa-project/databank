# frozen_string_literal: true

class GoogleDriveConnection < ApplicationRecord
  belongs_to :user
  belongs_to :dataset
  has_many :google_drive_imports, dependent: :destroy
  self.filter_attributes += [:encrypted_credentials]

  def self.encryptor
    key = Rails.application.key_generator.generate_key("google-drive-temporary-credentials-v1", 32)
    ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm", serializer: JSON)
  end

  def store_tokens!(client)
    if client.access_token.blank? || client.expires_at.nil?
      raise GoogleDrive::Error, "Google did not return valid authorization. Authorize Google Drive again."
    end

    credentials = encrypted_credentials.present? ? decrypt_credentials : {}
    credentials.merge!(
      "access_token"  => client.access_token,
      "expires_at"    => client.expires_at&.to_i,
      "refresh_token" => client.refresh_token.presence || credentials["refresh_token"]
    )
    if credentials["refresh_token"].blank?
      raise GoogleDrive::Error,
            "Google did not grant background access. Authorize again and allow access."
    end

    update!(encrypted_credentials: self.class.encryptor.encrypt_and_sign(credentials, purpose: "google-drive"))
  end

  def access_token(force_refresh: false)
    with_lock do
      if expires_at <= Time.current || encrypted_credentials.blank?
        raise GoogleDrive::Error,
              "Google authorization expired. Authorize Google Drive again."
      end

      credentials = decrypt_credentials
      if force_refresh || credentials["expires_at"].to_i <= 60.seconds.from_now.to_i
        client = GoogleDrive::Client.oauth_client(refresh_token: credentials.fetch("refresh_token"))
        GoogleDrive::Client.token_request(client)
        store_tokens!(client)
        credentials = decrypt_credentials
      end
      credentials.fetch("access_token")
    end
  end

  def release_if_unused!
    with_lock do
      unless google_drive_imports.where(status: GoogleDriveImport::ACTIVE_STATUSES).exists?
        update!(encrypted_credentials: nil)
      end
    end
  end

  private

  def decrypt_credentials
    self.class.encryptor.decrypt_and_verify(encrypted_credentials, purpose: "google-drive")
  rescue ActiveSupport::MessageEncryptor::InvalidMessage
    raise GoogleDrive::Error, "Stored Google authorization is unavailable. Authorize Google Drive again."
  end
end
