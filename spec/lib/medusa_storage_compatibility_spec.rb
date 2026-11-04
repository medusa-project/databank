require "spec_helper"
require "stringio"
require "medusa_storage"

RSpec.describe MedusaStorage::S3::ReadIO do
  let(:contents) { "storage compatibility" }
  let(:root) { double("storage root") }
  let(:reader) { described_class.new(root, "example.txt") }

  before do
    allow(root).to receive(:size).with("example.txt").and_return(contents.bytesize)
    allow(root).to receive(:get_bytes) do |key, start, length|
      expect(key).to eq("example.txt")
      StringIO.new(contents.byteslice(start, length))
    end
  end

  it "reads S3 content through the io-like API" do
    expect(reader.read(7)).to eq("storage")
    expect(reader.read).to eq(" compatibility")
    expect(reader.read(1)).to be_nil
  end

  it "supports seeking and rewinding" do
    reader.seek(8)
    expect(reader.read(13)).to eq("compatibility")

    reader.rewind
    expect(reader.read).to eq(contents)
  end
end
