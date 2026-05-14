require "rails_helper"

RSpec.describe Funder, type: :model do
  describe "associations" do
    it { should belong_to(:dataset) }
  end

  describe "validations" do
    it { should validate_presence_of(:dataset_id) }
  end

  describe "#display_info" do
    it "includes grant when present" do
      funder = described_class.new(name: "NSF", grant: "1234")

      expect(funder.display_info).to eq("NSF-Grant:1234")
    end

    it "returns name when grant is blank" do
      funder = described_class.new(name: "NIH", grant: nil)

      expect(funder.display_info).to eq("NIH")
    end
  end

  describe "#as_json" do
    it "returns a limited set of fields" do
      funder = described_class.create!(dataset: create(:dataset), name: "NSF", grant: "111")

      json = funder.as_json

      expect(json.keys).to include("name", "identifier", "identifier_scheme", "grant", "created_at", "updated_at")
      expect(json.keys).not_to include("id", "dataset_id")
    end
  end

  describe "nested update callback" do
    it "updates dataset nested_updated_at when created" do
      dataset = create(:dataset, nested_updated_at: nil)

      described_class.create!(dataset: dataset, name: "NSF")

      expect(dataset.reload.nested_updated_at).to be_present
    end
  end
end
