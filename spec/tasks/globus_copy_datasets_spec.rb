require "spec_helper"
require "rake"
require "aws-sdk-s3"
require "singleton"

RSpec.describe "globus:copy_datasets logging" do
  let(:task) { Rake::Task["globus:copy_datasets"] }
  let(:source) { double("source", root_type: :s3, name: "draft", bucket: "demo-main") }
  let(:destination) { double("destination", root_type: :s3, name: "globus_download", bucket: "demo-globus") }
  let(:datafile) do
    double("datafile", id: 3258, web_id: "4ds7w", binary_name: "lorem.txt",
                      storage_root: "draft", storage_key: "upload-key", current_root: source, in_globus: nil)
  end
  let(:dataset) { double("dataset", title: "Demo", key: "DEMO-123", datafiles: [datafile], files_public?: true) }

  before do
    stub_const("Dataset", double("Dataset", select: [dataset]))
    stub_const("StorageManager", Class.new { include Singleton })
    allow(StorageManager).to receive(:instance).and_return(double(globus_download_root: destination))
    allow(source).to receive(:s3_object).with("upload-key").and_return(double(key: "uploads/upload-key"))
    allow(destination).to receive(:s3_object).with("DEMO-123/lorem.txt").and_return(
      double(key: "downloads/DEMO-123/lorem.txt")
    )
    allow(destination).to receive(:exist?).and_return(false)
    allow(destination).to receive(:copy_content_to)
    @previous_rake_application = Rake.application
    Rake.application = Rake::Application.new
    Rake::Task.define_task(:environment)
    load File.expand_path("../../lib/tasks/globus.rake", __dir__)
  end

  after do
    Rake.application = @previous_rake_application
  end

  it "identifies copy-time 404s without claiming that the source is missing" do
    allow(destination).to receive(:copy_content_to).and_raise(Aws::S3::Errors::NotFound.new(nil, "missing"))

    expect { task.invoke }.to output(
      a_string_including(
        "S3 NotFound while copying source to destination; skipping file",
        'dataset="DEMO-123" datafile_id=3258', 'web_id="4ds7w" filename="lorem.txt"',
        "s3://demo-main/uploads/upload-key", "s3://demo-globus/downloads/DEMO-123/lorem.txt",
        "Aws::S3::Errors::NotFound: missing", "verify both locations"
      )
    ).to_stdout
  end

  it "identifies destination-check failures separately" do
    allow(destination).to receive(:exist?).and_raise(Aws::S3::Errors::NotFound.new(nil, "missing bucket"))
    expect(destination).not_to receive(:copy_content_to)

    expect { task.invoke }.to output(
      a_string_including("S3 NotFound while checking destination before copy", "missing bucket")
    ).to_stdout
  end

  it "reports an absent destination after a copy without marking the file copied" do
    expect(datafile).not_to receive(:update)

    expect { task.invoke }.to output(a_string_including("WARNING: destination absent after copy")).to_stdout
  end

  it "prints unexpected failures and preserves the exception" do
    error = Aws::S3::Errors::AccessDenied.new(nil, "denied")
    allow(destination).to receive(:copy_content_to).and_raise(error)

    expect do
      expect { task.invoke }.to raise_error(error)
    end.to output(a_string_including("ERROR: failed while copying source to destination", "AccessDenied: denied")).to_stdout
  end

  it "preserves skipping existing destination objects" do
    allow(destination).to receive(:exist?).and_return(true)
    allow(dataset).to receive(:all_globus).and_return(true)
    allow(datafile).to receive(:in_globus).and_return(true)
    expect(destination).not_to receive(:copy_content_to)
    expect(datafile).not_to receive(:update)

    expect { task.invoke }.to output("copying dataset: Demo, key: DEMO-123\n").to_stdout
  end
end
