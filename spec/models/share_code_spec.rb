require "rails_helper"

RSpec.describe ShareCode, type: :model do
  describe "associations" do
    it { should belong_to(:dataset) }
  end

  describe "callbacks" do
    it "sets code before create when blank" do
      share_code = described_class.create!(dataset: create(:dataset))

      expect(share_code.code).to be_present
    end
  end

  describe "#set_code" do
    it "keeps an existing code" do
      share_code = described_class.new(dataset: create(:dataset), code: "existing-code")

      share_code.set_code

      expect(share_code.code).to eq("existing-code")
    end
  end

  describe "#generate_code" do
    it "retries until a unique code is produced" do
      create(:dataset).create_share_code(code: "duplicate-code")
      share_code = described_class.new(dataset: create(:dataset))

      allow(SecureRandom).to receive(:urlsafe_base64).and_return("duplicate-code", "unique-code")

      expect(share_code.generate_code).to eq("unique-code")
    end
  end
end
