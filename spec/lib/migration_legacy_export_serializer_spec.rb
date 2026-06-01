require "rails_helper"
require "rake"

Rails.application.load_tasks if Rake::Task.tasks.empty?

RSpec.describe Migration::Legacy::ExportSerializer do
  it "serializes dataset notes into the export payload" do
    empty_relation = double("empty_relation")
    allow(empty_relation).to receive(:order).and_return([])

    first_note = instance_double(
      "Note",
      body: "Flagged for curator follow-up",
      author: "curator-one@example.edu",
      created_at: Time.utc(2026, 6, 1, 9, 0, 0),
      updated_at: Time.utc(2026, 6, 1, 10, 0, 0)
    )
    second_note = instance_double(
      "Note",
      body: "Metadata corrected",
      author: "curator-two@example.edu",
      created_at: Time.utc(2026, 6, 1, 11, 0, 0),
      updated_at: Time.utc(2026, 6, 1, 11, 30, 0)
    )
    notes_relation = double("notes_relation")
    allow(notes_relation).to receive(:order).with(:created_at, :id).and_return([ first_note, second_note ])

    dataset = instance_double(
      "Dataset",
      key: "IDB-1234567",
      title: "Legacy Dataset",
      identifier: "10.13012/B2IDB-1234567_V1",
      publisher: "Illinois Data Bank",
      publication_year: 2026,
      description: "Legacy dataset description",
      license: "CC0",
      corresponding_creator_name: "Ada Lovelace",
      depositor_name: "Legacy Depositor",
      depositor_email: "legacy@example.edu",
      subject: "Computer Science",
      keywords: "legacy,parity",
      publication_state: "released",
      hold_state: nil,
      release_date: Date.new(2026, 6, 1),
      embargo: "none",
      is_test: false,
      is_import: false,
      tombstone_date: nil,
      dataset_version: 1,
      created_at: Time.utc(2026, 6, 1, 8, 0, 0),
      updated_at: Time.utc(2026, 6, 1, 12, 0, 0),
      creators: empty_relation,
      contributors: empty_relation,
      funders: empty_relation,
      related_materials: empty_relation,
      datafiles: empty_relation,
      notes: notes_relation,
      id: 42
    )

    allow(User).to receive(:find_by).with(email: "legacy@example.edu").and_return(nil)

    payload = described_class.new(dataset).as_json

    expect(payload[:notes]).to eq([
      {
        body: "Flagged for curator follow-up",
        author: "curator-one@example.edu",
        created_at: Time.utc(2026, 6, 1, 9, 0, 0),
        updated_at: Time.utc(2026, 6, 1, 10, 0, 0)
      },
      {
        body: "Metadata corrected",
        author: "curator-two@example.edu",
        created_at: Time.utc(2026, 6, 1, 11, 0, 0),
        updated_at: Time.utc(2026, 6, 1, 11, 30, 0)
      }
    ])
  end
end