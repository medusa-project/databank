require "rails_helper"

RSpec.describe RelatedMaterial, type: :model do
  describe "associations" do
    it { should belong_to(:dataset) }
  end

  describe "#relationship_arr" do
    it "splits and trims datacite_list" do
      material = described_class.new(datacite_list: "Cites, IsSupplementTo")

      expect(material.relationship_arr).to eq(["Cites", "IsSupplementTo"])
    end

    it "returns empty array when datacite_list is blank" do
      material = described_class.new(datacite_list: "")

      expect(material.relationship_arr).to eq([])
    end
  end

  describe "#nonversion_relationships" do
    it "removes version-only relationship values" do
      material = described_class.new(datacite_list: "IsPreviousVersionOf, Cites, IsNewVersionOf")

      expect(material.nonversion_relationships).to eq(["Cites"])
    end
  end

  describe "#display_info" do
    it "joins present fields" do
      material = described_class.new(material_type: "Article", link: "https://example.org", citation: "Doe 2024")

      expect(material.display_info).to eq("Article, https://example.org, Doe 2024")
    end
  end

  describe "#link_status" do
    it "returns no non-version related materials when there are none" do
      material = described_class.new(datacite_list: "IsPreviousVersionOf")

      expect(material.link_status).to eq("no non-version related materials")
    end

    it "returns no link when non-version relationships exist but link is missing" do
      material = described_class.new(datacite_list: "Cites", link: nil)

      expect(material.link_status).to eq("no link")
    end

    it "returns invalid url when link format is invalid" do
      material = described_class.new(datacite_list: "Cites", link: "not-a-url")

      expect(material.link_status).to eq("invalid url")
    end

    it "delegates to link attempt status for valid URLs" do
      material = described_class.new(datacite_list: "Cites", link: "https://example.org")
      allow(material).to receive(:link_attempt_status).and_return("ok")

      expect(material.link_status).to eq("ok")
    end
  end

  describe "nested update callback" do
    it "updates dataset nested_updated_at when created" do
      dataset = create(:dataset, nested_updated_at: nil)

      described_class.create!(dataset: dataset)

      expect(dataset.reload.nested_updated_at).to be_present
    end
  end
end
