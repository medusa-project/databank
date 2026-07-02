require "rails_helper"
require "rake"
require "json"

RSpec.describe "migration local rehearsal tasks" do
  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
  end

  let(:seed_task) { Rake::Task["testing:seed_migration_test_data"] }
  let(:export_test_task) { Rake::Task["migration:legacy:export_test_bundle"] }
  let(:seed_keys) { %w[TESTIDB-MIGRATE1 TESTIDB-MIGRATE2 TESTIDB-MIGRATE3] }

  before do
    seed_task.reenable
    export_test_task.reenable
  end

  after do
    ENV.delete("RESET")
    ENV.delete("OUTPUT_ROOT")
    ENV.delete("KEYS")
  end

  it "seeds deterministic migration datasets for local export/import rehearsal" do
    ENV["RESET"] = "true"

    expect { seed_task.invoke }.not_to raise_error

    datasets = Dataset.where(key: seed_keys).order(:key)
    expect(datasets.count).to eq(3)

    full = Dataset.find_by!(key: "TESTIDB-MIGRATE1")
    minimal = Dataset.find_by!(key: "TESTIDB-MIGRATE2")
    multi = Dataset.find_by!(key: "TESTIDB-MIGRATE3")

    expect(full.datafiles.count).to eq(1)
    expect(full.datafiles.first.nested_items.count).to be >= 3
    expect(full.creators.count).to eq(2)
    expect(full.contributors.count).to eq(1)
    expect(full.funders.count).to eq(1)

    expect(minimal.datafiles.count).to eq(1)
    expect(minimal.funders.count).to eq(0)

    expect(multi.datafiles.count).to eq(2)
    expect(multi.datafiles.where(binary_name: "package.tar.gz").first.nested_items.count).to be >= 2
  ensure
    ENV["RESET"] = "true"
    seed_task.reenable
    seed_task.invoke
  end

  it "exports a flat test bundle with manifest and checksum for explicit keys" do
    output_root = Rails.root.join("tmp", "migration_test_export_spec")
    FileUtils.rm_rf(output_root)
    FileUtils.mkdir_p(output_root)

    ENV["RESET"] = "true"
    seed_task.invoke

    export_test_task.reenable
    ENV["OUTPUT_ROOT"] = output_root.to_s
    ENV["KEYS"] = seed_keys.join(",")

    expect { export_test_task.invoke }.not_to raise_error

    run_dir = Dir.glob(output_root.join("dataset_flat_test_*"))
             .map { |path| Pathname(path) }
             .max_by { |path| File.mtime(path) }
    expect(run_dir).not_to be_nil

    bundle_path = run_dir.join("legacy_datasets.ndjson")
    checksum_path = run_dir.join("legacy_datasets.ndjson.sha256")
    manifest_path = run_dir.join("manifest.json")

    expect(bundle_path).to exist
    expect(checksum_path).to exist
    expect(manifest_path).to exist

    manifest = JSON.parse(File.read(manifest_path))
    expect(manifest["format_version"]).to eq(2)
    expect(manifest["format_type"]).to eq("flat")
    expect(manifest["test_bundle"]).to eq(true)
    expect(manifest.dig("record_counts", "datasets")).to eq(3)

    lines = File.readlines(bundle_path).map(&:strip).reject(&:empty?)
    types = lines.map { |line| JSON.parse(line).fetch("type") }

    expect(types).to include("dataset")
    expect(types).to include("datafile")
    expect(types).to include("nested_item")
  ensure
    ENV["RESET"] = "true"
    seed_task.reenable
    seed_task.invoke
    FileUtils.rm_rf(output_root)
  end
end
