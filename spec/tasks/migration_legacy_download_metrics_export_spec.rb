# frozen_string_literal: true

require "rails_helper"
require "rake"
require "json"

RSpec.describe "migration:legacy export_download_metrics_bundle" do
  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
  end

  let(:export_task) { Rake::Task["migration:legacy:export_download_metrics_bundle"] }

  before do
    export_task.reenable
  end

  after do
    ENV.delete("OUTPUT_ROOT")
    ENV.delete("INCLUDE_TESTS")
    ENV.delete("SINCE")
    ENV.delete("UNTIL")
  end

  def latest_run_dir(output_root)
    Dir.glob(output_root.join("download_metrics_*"))
      .map { |path| Pathname(path) }
      .max_by { |path| File.mtime(path) }
  end

  it "exports dataset, file, and day download tallies while excluding test datasets by default" do
    output_root = Rails.root.join("tmp", "legacy_download_metrics_export_spec")
    FileUtils.rm_rf(output_root)
    FileUtils.mkdir_p(output_root)

    since_time = Time.utc(2030, 1, 1, 0, 0, 0)
    until_time = Time.utc(2030, 1, 2, 0, 0, 0)

    non_test_dataset = create(:dataset, key: "IDB-LEGACY-1000001", is_test: false)
    test_dataset = create(:dataset, key: "IDB-LEGACY-1000002", is_test: true)

    create(:dataset_download_tally,
           dataset_key: non_test_dataset.key,
           doi: "10.13012/B2IDB-LEGACY-1000001_V1",
           download_date: Date.new(2026, 6, 1),
           tally: 3,
          created_at: Time.utc(2030, 1, 1, 10, 0, 0),
          updated_at: Time.utc(2030, 1, 1, 10, 0, 0))
    create(:dataset_download_tally,
           dataset_key: test_dataset.key,
           doi: "10.13012/B2IDB-LEGACY-1000002_V1",
           download_date: Date.new(2026, 6, 1),
           tally: 7,
          created_at: Time.utc(2030, 1, 1, 10, 0, 0),
          updated_at: Time.utc(2030, 1, 1, 10, 0, 0))

    create(:file_download_tally,
           file_web_id: "file-legacy-1",
           filename: "example.csv",
           dataset_key: non_test_dataset.key,
           doi: "10.13012/B2IDB-LEGACY-1000001_V1",
           download_date: Date.new(2026, 6, 1),
           tally: 5,
          created_at: Time.utc(2030, 1, 1, 10, 0, 0),
          updated_at: Time.utc(2030, 1, 1, 10, 0, 0))

            DayFileDownload.create!(
              ip_address: "127.0.0.1",
              file_web_id: "file-legacy-1",
              filename: "example.csv",
              dataset_key: non_test_dataset.key,
              doi: "10.13012/B2IDB-LEGACY-1000001_V1",
              download_date: Date.new(2026, 6, 1),
              created_at: Time.utc(2030, 1, 1, 12, 0, 0),
              updated_at: Time.utc(2030, 1, 1, 12, 0, 0)
            )

    ENV["OUTPUT_ROOT"] = output_root.to_s
            ENV["SINCE"] = since_time.iso8601
            ENV["UNTIL"] = until_time.iso8601

    expect { export_task.invoke }.not_to raise_error

    run_dir = latest_run_dir(output_root)
    expect(run_dir).not_to be_nil

    bundle_path = run_dir.join("legacy_download_metrics.ndjson")
    manifest_path = run_dir.join("manifest.json")
    checksum_path = run_dir.join("legacy_download_metrics.ndjson.sha256")

    expect(bundle_path).to exist
    expect(manifest_path).to exist
    expect(checksum_path).to exist

    manifest = JSON.parse(File.read(manifest_path))
    expect(manifest["format_version"]).to eq(1)
    expect(manifest["include_tests"]).to eq(false)
    expect(manifest["record_count"]).to eq(3)
    expect(manifest.dig("counts", "DatasetDownloadTally")).to eq(1)
    expect(manifest.dig("counts", "FileDownloadTally")).to eq(1)
    expect(manifest.dig("counts", "DayFileDownload")).to eq(1)

    types = File.readlines(bundle_path, chomp: true)
                .reject(&:blank?)
                .map { |line| JSON.parse(line).fetch("type") }

    expect(types).to contain_exactly("DatasetDownloadTally", "FileDownloadTally", "DayFileDownload")
  ensure
    FileUtils.rm_rf(output_root)
  end

  it "includes test dataset tallies when INCLUDE_TESTS is true" do
    output_root = Rails.root.join("tmp", "legacy_download_metrics_export_include_tests_spec")
    FileUtils.rm_rf(output_root)
    FileUtils.mkdir_p(output_root)

    since_time = Time.utc(2030, 1, 1, 0, 0, 0)
    until_time = Time.utc(2030, 1, 2, 0, 0, 0)

    dataset = create(:dataset, key: "IDB-LEGACY-2000001", is_test: true)

    create(:dataset_download_tally,
           dataset_key: dataset.key,
           doi: "10.13012/B2IDB-LEGACY-2000001_V1",
           download_date: Date.new(2026, 6, 2),
           tally: 4,
          created_at: Time.utc(2030, 1, 1, 10, 0, 0),
          updated_at: Time.utc(2030, 1, 1, 10, 0, 0))

    ENV["OUTPUT_ROOT"] = output_root.to_s
    ENV["INCLUDE_TESTS"] = "true"
        ENV["SINCE"] = since_time.iso8601
        ENV["UNTIL"] = until_time.iso8601

    expect { export_task.invoke }.not_to raise_error

    run_dir = latest_run_dir(output_root)
    expect(run_dir).not_to be_nil

    manifest = JSON.parse(File.read(run_dir.join("manifest.json")))
    expect(manifest["include_tests"]).to eq(true)
    expect(manifest.dig("counts", "DatasetDownloadTally")).to eq(1)
  ensure
    FileUtils.rm_rf(output_root)
  end
end