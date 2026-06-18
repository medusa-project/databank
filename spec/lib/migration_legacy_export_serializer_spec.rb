require "rails_helper"
require "rake"

Rails.application.load_tasks if Rake::Task.tasks.empty?

RSpec.describe Migration::Legacy::ExportSerializer do
  it "serializes related material relationship assertions" do
    related_material = instance_double(
      "RelatedMaterial",
      material_type: "Article",
      selected_type: "Article",
      availability: nil,
      link: "https://example.org/article",
      uri: "10.1000/example",
      uri_type: "DOI",
      citation: "Example citation",
      note: "Curator note",
      relationship_arr: [ "IsSupplementTo", "IsCitedBy" ],
      created_at: Time.utc(2026, 6, 1, 9, 0, 0),
      updated_at: Time.utc(2026, 6, 1, 10, 0, 0)
    )

    related_relation = double("related_relation")
    empty_relation = double("empty_relation")
    allow(related_relation).to receive(:order).with(:id).and_return([ related_material ])
    allow(empty_relation).to receive(:order).and_return([])

    dataset = instance_double(
      "Dataset",
      key: "IDB-1234000",
      title: "Legacy Dataset",
      identifier: "10.13012/B2IDB-1234000_V1",
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
      nested_updated_at: Time.utc(2026, 6, 1, 12, 30, 0),
      created_at: Time.utc(2026, 6, 1, 8, 0, 0),
      updated_at: Time.utc(2026, 6, 1, 12, 0, 0),
      creators: empty_relation,
      contributors: empty_relation,
      funders: empty_relation,
      related_materials: related_relation,
      datafiles: empty_relation,
      notes: empty_relation,
      id: 44
    )

    allow(User).to receive(:find_by).with(email: "legacy@example.edu").and_return(nil)

    payload = described_class.new(dataset).as_json

    expect(payload[:related_materials].first[:datacite_list]).to eq("IsSupplementTo,IsCitedBy")
    expect(payload[:related_materials].first[:relation_types]).to eq([ "IsSupplementTo", "IsCitedBy" ])
    expect(payload[:related_materials].first[:relation_type]).to eq("IsSupplementTo")
    expect(payload[:related_materials].first[:selected_type]).to eq("Article")
    expect(payload[:related_materials].first[:note]).to eq("Curator note")
  end

  it "serializes creator and contributor identifier_scheme values" do
    creator = instance_double(
      "Creator",
      family_name: "Lovelace",
      given_name: "Ada",
      institution_name: nil,
      email: "ada@example.edu",
      identifier: "0000-0001-2345-6789",
      identifier_scheme: "ORCID",
      is_contact: true,
      row_position: 1,
      created_at: Time.utc(2026, 6, 1, 9, 0, 0),
      updated_at: Time.utc(2026, 6, 1, 10, 0, 0)
    )

    contributor = instance_double(
      "Contributor",
      family_name: "Hopper",
      given_name: "Grace",
      institution_name: nil,
      identifier: "https://ror.org/03yrm5c26",
      identifier_scheme: "ROR",
      row_position: 1,
      created_at: Time.utc(2026, 6, 1, 11, 0, 0),
      updated_at: Time.utc(2026, 6, 1, 11, 30, 0)
    )

    creators_relation = double("creators_relation")
    contributors_relation = double("contributors_relation")
    empty_relation = double("empty_relation")

    allow(creators_relation).to receive(:order).with(:row_position, :id).and_return([ creator ])
    allow(contributors_relation).to receive(:order).with(:row_position, :id).and_return([ contributor ])
    allow(empty_relation).to receive(:order).and_return([])

    dataset = instance_double(
      "Dataset",
      key: "IDB-1234568",
      title: "Legacy Dataset",
      identifier: "10.13012/B2IDB-1234568_V1",
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
      nested_updated_at: Time.utc(2026, 6, 1, 12, 30, 0),
      created_at: Time.utc(2026, 6, 1, 8, 0, 0),
      updated_at: Time.utc(2026, 6, 1, 12, 0, 0),
      creators: creators_relation,
      contributors: contributors_relation,
      funders: empty_relation,
      related_materials: empty_relation,
      datafiles: empty_relation,
      notes: empty_relation,
      id: 43
    )

    allow(User).to receive(:find_by).with(email: "legacy@example.edu").and_return(nil)

    payload = described_class.new(dataset).as_json

    expect(payload[:creators].first[:identifier_scheme]).to eq("ORCID")
    expect(payload[:contributors].first[:identifier_scheme]).to eq("ROR")
  end

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
      nested_updated_at: Time.utc(2026, 6, 1, 12, 30, 0),
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

    expect(payload[:nested_updated_at]).to eq(Time.utc(2026, 6, 1, 12, 30, 0))

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

RSpec.describe Migration::Legacy::UserExportSerializer do
  it "maps supported legacy roles to importable databank-2 roles" do
    user = instance_double(
      "User",
      provider: "shibboleth",
      uid: "person@illinois.edu",
      email: "Person@Illinois.edu",
      username: "person",
      name: "Person Example",
      role: Databank::UserRole::ADMIN,
      created_at: Time.utc(2026, 6, 18, 20, 0, 0),
      updated_at: Time.utc(2026, 6, 18, 20, 5, 0)
    )

    payload = described_class.new(user).as_json

    expect(payload[:type]).to eq("User")
    expect(payload.dig(:attributes, :provider)).to eq("shibboleth")
    expect(payload.dig(:attributes, :uid)).to eq("person@illinois.edu")
    expect(payload.dig(:attributes, :email)).to eq("person@illinois.edu")
    expect(payload.dig(:attributes, :role)).to eq(Databank::UserRole::ADMIN)
    expect(payload.dig(:attributes, :mapped_role)).to eq("curator")
  end

  it "flags deprecated reviewer roles as skipped" do
    user = instance_double(
      "User",
      provider: "developer",
      uid: "reviewer@example.edu",
      email: "reviewer@example.edu",
      username: "reviewer",
      name: "Reviewer Example",
      role: Databank::UserRole::NETWORK_REVIEWER,
      created_at: Time.utc(2026, 6, 18, 20, 0, 0),
      updated_at: Time.utc(2026, 6, 18, 20, 5, 0)
    )

    serializer = described_class.new(user)

    expect(serializer.exportable?).to eq(false)
    expect(serializer.skip_reason).to eq("unsupported_role")
  end
end

RSpec.describe Migration::Legacy::AuditExportSerializer do
  it "serializes audit rows with stable dataset and nested record locators" do
    dataset = instance_double("Dataset", key: "IDB-1234999")
    creator = instance_double(
      "Creator",
      row_position: 1,
      given_name: "Ada",
      family_name: "Lovelace",
      institution_name: nil
    )

    audit = instance_double(
      "Audited::Audit",
      id: 77,
      action: "update",
      version: 3,
      comment: "corrected creator metadata",
      remote_address: "127.0.0.1",
      request_uuid: "req-123",
      created_at: Time.utc(2026, 6, 18, 18, 0, 0),
      audited_changes: { "family_name" => [ "Byron", "Lovelace" ] },
      username: "curator@example.edu",
      user_type: "User",
      user_id: 9,
      auditable_type: "Creator",
      auditable_id: 12,
      associated_type: "Dataset",
      associated_id: 55,
      auditable: creator,
      associated: dataset
    )

    payload = described_class.new(audit: audit, dataset: dataset).as_json

    expect(payload[:type]).to eq("Audit")
    expect(payload.dig(:attributes, :dataset_key)).to eq("IDB-1234999")
    expect(payload.dig(:attributes, :auditable, :legacy_id)).to eq(12)
    expect(payload.dig(:attributes, :auditable, :locator)).to eq(
      row_position: 1,
      given_name: "Ada",
      family_name: "Lovelace",
      name: "Ada Lovelace"
    )
    expect(payload.dig(:attributes, :associated, :locator)).to eq(key: "IDB-1234999")
  end
end