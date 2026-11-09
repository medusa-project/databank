require "rails_helper"
require "rake"

Rails.application.load_tasks if Rake::Task.tasks.empty?

RSpec.describe Migration::Legacy::ExportSerializer do
  let(:additional_dataset_attributes) do
    {
      corresponding_creator_email: "ada@example.edu",
      all_globus: false,
      all_medusa: true,
      complete: true,
      org_creators: false,
      external_files_link: nil,
      external_files_note: nil,
      medusa_dataset_dir: "datasets/example",
      suppress_changelog: false,
      version_comment: "Initial version",
      have_permission: "yes",
      removed_private: "na",
      agree: "yes"
    }
  end

  before do
    allow(Token).to receive(:where).with(dataset_key: kind_of(String)).and_return(Token.none)
  end

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
      **additional_dataset_attributes,
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
      **additional_dataset_attributes,
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
      **additional_dataset_attributes,
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

    expect(payload).to include(additional_dataset_attributes)
    expect(payload[:token]).to be_nil
    expect(payload[:owner_uid]).to eq("legacy:legacy@example.edu")
    expect(payload[:url]).to eq("#{IDB_CONFIG[:root_url_text]}/datasets/IDB-1234567.json")
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

RSpec.describe "Legacy export JSON compatibility" do
  let(:dataset) do
    Dataset.new(
      key: "IDB-1234567",
      title: "Measurements <draft>",
      depositor_email: "legacy@example.edu",
      release_date: Date.new(2026, 6, 1),
      created_at: Time.utc(2026, 6, 1, 8, 0, 0),
      updated_at: Time.utc(2026, 6, 1, 12, 0, 0)
    )
  end
  let(:serializers) do
    [
      Migration::Legacy::ExportSerializer.new(dataset),
      Migration::Legacy::AuditExportSerializer.new(audit: Audited::Audit.new, dataset: dataset),
      Migration::Legacy::GuideExportSerializer.new(Guide::Section.new),
      Migration::Legacy::FeaturedResearcherExportSerializer.new(FeaturedResearcher.new),
      Migration::Legacy::UserExportSerializer.new(User.new),
      Migration::Legacy::PermissionExportSerializer.new(
        type: "Depositor", email: "legacy@example.edu", user_provider: "shibboleth", user_uid: "legacy"
      ),
      Migration::Legacy::DatasetAccessGrantExportSerializer.new(
        dataset_key: dataset.key, email: "legacy@example.edu", access_level: "read",
        user_provider: "shibboleth", user_uid: "legacy", legacy_resource_id: 1, abilities: ["read"]
      ),
      Migration::Legacy::MedusaIngestExportSerializer.new(MedusaIngest.new(idb_class: "dataset")),
      Migration::Legacy::DatasetDownloadTallyExportSerializer.new(DatasetDownloadTally.new),
      Migration::Legacy::FileDownloadTallyExportSerializer.new(FileDownloadTally.new),
      Migration::Legacy::DayFileDownloadExportSerializer.new(DayFileDownload.new)
    ]
  end

  before do
    allow(User).to receive(:find_by).with(email: dataset.depositor_email).and_return(nil)
    allow(Token).to receive(:where).with(dataset_key: dataset.key).and_return(Token.none)
  end

  it "accepts Rails JSON options without changing the export fields" do
    serializers.each do |serializer|
      aggregate_failures(serializer.class.name) do
        expect(serializer.as_json(nil)).to eq(serializer.as_json)
        expect(serializer.as_json(escape_html_entities: false)).to eq(serializer.as_json)
      end
    end
  end

  it "encodes each serializer through Rails with the same result as its payload" do
    serializers.each do |serializer|
      aggregate_failures(serializer.class.name) do
        expect(ActiveSupport::JSON.encode(serializer)).to eq(ActiveSupport::JSON.encode(serializer.as_json))
        expect(ActiveSupport::JSON.encode(serializer, escape_html_entities: false)).to eq(
          ActiveSupport::JSON.encode(serializer.as_json, escape_html_entities: false)
        )
      end
    end
  end

  it "preserves dataset fields in the flat NDJSON export" do
    nested = Migration::Legacy::ExportSerializer.new(dataset).as_json
    flat = Migration::Legacy::FlatExportSerializer.serialize_dataset(dataset)

    expect(flat.except(:type, :dataset_id)).to eq(nested.except(:key, :url, :datafiles))
    decoded = JSON.parse(JSON.generate(flat))
    expect(decoded).to include(
      "type" => "dataset",
      "dataset_id" => dataset.key,
      "title" => "Measurements <draft>",
      "release_date" => "2026-06-01",
      "created_at" => "2026-06-01 08:00:00 UTC",
      "updated_at" => "2026-06-01 12:00:00 UTC"
    )
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