# frozen_string_literal: true

class BoxConnection < ApplicationRecord
  belongs_to :user
  belongs_to :dataset
  has_many :box_imports, dependent: :destroy
  self.filter_attributes += [:encrypted_credentials]

  def self.encryptor
    key = Rails.application.key_generator.generate_key("box-temporary-credentials-v1", 32)
    ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm", serializer: JSON)
  end

  def store_tokens!(tokens)
    unless tokens["access_token"].present? && tokens["refresh_token"].present? &&
           tokens["expires_in"].to_i.positive?
      raise BoxStorage::Error, "Box did not return valid authorization. Authorize Box again."
    end
    credentials = tokens.slice("access_token", "refresh_token")
    credentials["expires_at"] = Time.current.to_i + tokens.fetch("expires_in").to_i
    update!(encrypted_credentials: self.class.encryptor.encrypt_and_sign(credentials, purpose: "box"))
  end

  def access_token(force_refresh: false)
    with_lock do
      if expires_at <= Time.current || encrypted_credentials.blank?
        raise BoxStorage::Error, "Box authorization expired. Authorize Box again."
      end
      credentials = self.class.encryptor.decrypt_and_verify(encrypted_credentials, purpose: "box")
      if force_refresh || credentials.fetch("expires_at") <= 60.seconds.from_now.to_i
        # Box refresh tokens rotate and can be used only once; persist under this lock.
        tokens = BoxStorage::Client.token_request(grant_type: "refresh_token",
                                                  refresh_token: credentials.fetch("refresh_token"))
        store_tokens!(tokens)
        credentials["access_token"] = tokens.fetch("access_token")
      end
      credentials.fetch("access_token")
    end
  rescue ActiveSupport::MessageEncryptor::InvalidMessage
    raise BoxStorage::Error, "Stored Box authorization is unavailable. Authorize Box again."
  end

  def release_if_unused!
    with_lock do
      update!(encrypted_credentials: nil) unless box_imports.where(status: BoxImport::ACTIVE_STATUSES).exists?
    end
  end
end
