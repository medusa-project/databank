# frozen_string_literal: true

require "rails_helper"

RSpec.describe CloudImports do
  describe ".part_bytes" do
    it "keeps files up to 50 GB at 8 MiB" do
      expect(described_class.part_bytes(50_000_000_000)).to eq(8 * 1024 * 1024)
    end

    it "calculates the part size needed for 150 GB" do
      expect(described_class.part_bytes(150_000_000_000)).to eq(17_647_059)
    end

    it "fits a 150 GB file within the target part count" do
      size = 150_000_000_000
      part = described_class.part_bytes(size)
      expect((size + part - 1) / part).to eq(8_500)
    end
  end
end
