require "rails_helper"

RSpec.describe Token, type: :model do
  describe ".generate_auth_token" do
    it "returns a 32-character hex token without hyphens" do
      token = described_class.generate_auth_token

      expect(token.length).to eq(32)
      expect(token).to match(/\A[0-9a-f]+\z/)
      expect(token).not_to include("-")
    end

    it "returns different values across calls" do
      token_one = described_class.generate_auth_token
      token_two = described_class.generate_auth_token

      expect(token_one).not_to eq(token_two)
    end
  end
end
