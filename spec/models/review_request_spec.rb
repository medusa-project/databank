require "rails_helper"

RSpec.describe ReviewRequest, type: :model do
  describe "#dataset" do
    it "finds dataset by dataset_key" do
      dataset = create(:dataset)
      review_request = described_class.new(dataset_key: dataset.key)

      expect(review_request.dataset).to eq(dataset)
    end
  end

  describe "#next_review_request" do
    it "returns the next request for the same dataset key" do
      key = "TEST-KEY"
      current = described_class.create!(dataset_key: key, requested_at: 2.hours.ago)
      _other_dataset = described_class.create!(dataset_key: "OTHER", requested_at: 1.hour.ago)
      next_request = described_class.create!(dataset_key: key, requested_at: 1.hour.ago)

      expect(current.next_review_request).to eq(next_request)
    end
  end

  describe "#change_log" do
    it "returns audit changes sorted descending when no next request exists" do
      audit = instance_double("Audit", action: "update", audited_changes: { "title" => ["a", "b"] }, created_at: Time.current)
      audits_relation = instance_double("AuditsRelation")

      review_request = described_class.new(dataset_key: "TEST", requested_at: 1.hour.ago)
      allow(review_request).to receive(:next_review_request).and_return(nil)
      allow(review_request).to receive(:audits_since).with(review_request.requested_at).and_return(audits_relation)
      allow(audits_relation).to receive(:order).with(created_at: :desc).and_return([audit])

      expect(review_request.change_log).to eq([
        {
          action: "update",
          audited_changes: { "title" => ["a", "b"] },
          created_at: audit.created_at
        }
      ])
    end

    it "limits audits to before the next request when one exists" do
      next_request = described_class.new(requested_at: Time.current)
      filtered_relation = instance_double("FilteredRelation")
      audits_relation = instance_double("AuditsRelation")

      review_request = described_class.new(dataset_key: "TEST", requested_at: 2.hours.ago)
      allow(review_request).to receive(:next_review_request).and_return(next_request)
      allow(review_request).to receive(:audits_since).with(review_request.requested_at).and_return(audits_relation)
      allow(audits_relation).to receive(:where).with("created_at < ?", next_request.requested_at).and_return(filtered_relation)
      allow(filtered_relation).to receive(:order).with(created_at: :desc).and_return([])

      expect(review_request.change_log).to eq([])
    end
  end
end
