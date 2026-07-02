require "rails_helper"
require "rake"
require "json"

RSpec.describe "testing:seed_from_old_bundle_values" do
  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
  end

  let(:task) { Rake::Task["testing:seed_from_old_bundle_values"] }
  let(:bundle_path) { Rails.root.join("tmp", "old_bundle_values_spec.ndjson") }

  before do
    task.reenable
  end

  after do
    ENV.delete("SOURCE_BUNDLE")
    ENV.delete("LIMIT")
    ENV.delete("RESET")
    ENV.delete("KEY_PREFIX")
    FileUtils.rm_f(bundle_path)
    Dataset.where("key LIKE ?", "LEGACYBUNDLE-SPEC-%").find_each do |dataset|
      NestedItem.where(datafile_id: dataset.datafiles.pluck(:id)).delete_all
      dataset.datafiles.delete_all
      dataset.creators.delete_all
      dataset.contributors.delete_all
      dataset.funders.delete_all
      dataset.related_materials.delete_all
      dataset.notes.delete_all
      Token.where(dataset_key: dataset.key).delete_all
      dataset.delete
    end
  end

  it "imports sample values from old-style ndjson into legacy records" do
    dataset_payload = {
      key: "SPEC-001",
      title: "Imported Sample Dataset",
      identifier: "",
      publisher: "University of Illinois Urbana-Champaign",
      description: "Imported from old-style bundle for local testing",
      license: "CC01",
      corresponding_creator_name: "Sample Person",
      depositor_name: "Sample Person",
      depositor_email: "sample@example.edu",
      owner_uid: "sample@example.edu",
      publication_state: "draft",
      hold_state: "none",
      embargo: "none",
      is_test: true,
      is_import: false,
      dataset_version: "1",
      creators: [
        {
          family_name: "Person",
          given_name: "Sample",
          email: "sample@example.edu",
          identifier: "",
          identifier_scheme: "ORCID",
          is_contact: true,
          row_position: 1,
          type_of: 0
        }
      ],
      contributors: [],
      funders: [
        {
          name: "NSF",
          identifier: "",
          identifier_scheme: "",
          grant: "NSF-1"
        }
      ],
      related_materials: [
        {
          material_type: "Article",
          selected_type: "Article",
          availability: "Published",
          link: "https://example.com/article",
          uri: "https://example.com/article",
          uri_type: "URL",
          citation: "Sample Citation",
          datacite_list: "IsSupplementTo",
          relation_type: "IsSupplementTo"
        }
      ],
      notes: [
        {
          author: "curator@example.com",
          body: "seed note"
        }
      ],
      token: {
        identifier: "token-123",
        expires: 1.day.from_now
      },
      datafiles: [
        {
          web_id: "ab123",
          binary_name: "sample.csv",
          binary_size: 123,
          storage_root: "draft",
          storage_key: "spec/sample.csv",
          peek_type: "code",
          peek_text: "a,b,c",
          nested_items: [
            {
              id: 1,
              parent_id: nil,
              item_name: "sample.csv",
              item_path: "sample.csv",
              is_directory: false,
              media_type: "text/csv",
              size: 123
            }
          ]
        }
      ]
    }

    File.write(bundle_path, JSON.generate(dataset_payload) + "\n")

    ENV["SOURCE_BUNDLE"] = bundle_path.to_s
    ENV["LIMIT"] = "1"
    ENV["KEY_PREFIX"] = "LEGACYBUNDLE-SPEC-"

    expect { task.invoke }.not_to raise_error

    dataset = Dataset.find_by!(key: "LEGACYBUNDLE-SPEC-SPEC-001")
    expect(dataset.title).to eq("Imported Sample Dataset")
    expect(dataset.depositor_email).to eq("sample@example.edu")
    expect(dataset.creators.count).to eq(1)
    expect(dataset.funders.count).to eq(1)
    expect(dataset.related_materials.count).to eq(1)
    expect(dataset.notes.count).to eq(1)
    expect(dataset.datafiles.count).to eq(1)
    expect(dataset.datafiles.first.nested_items.count).to eq(1)
  end
end
