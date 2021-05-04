class ShareCode < ApplicationRecord
  belongs_to :dataset
  before_create :set_code

  def set_code
    self.code ||= generate_code
  end

  # Generates a guaranteed-unique code
  def generate_code
    proposed_code = nil
    loop do
      proposed_code = SecureRandom.urlsafe_base64(64, false)
      break unless self.class.find_by(code: proposed_code)
    end
    proposed_code
  end
end
