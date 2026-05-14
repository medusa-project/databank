require 'rails_helper'

RSpec.describe CuratorReport, type: :model do
  let(:storage_root) do
    double('storage_root', root_type: :s3, name: 'report-root', bucket: 'report-bucket', prefix: 'reports/')
  end

  let(:report) do
    r = CuratorReport.new(
      requestor_name: 'Curator One',
      requestor_email: 'curator@illinois.edu',
      report_type: Databank::ReportType::FILE_AUDIT,
      storage_root: 'report-root',
      storage_key: 'file_audit_report-1_2026-05-01_10-00-00.csv'
    )
    r.id = 1
    r
  end

  before do
    allow(StorageManager.instance).to receive(:root_set)
      .and_return(double('root_set', at: storage_root))
  end

  describe '#current_root' do
    it 'returns the storage root matching the stored name' do
      expect(report.current_root).to eq(storage_root)
    end

    it 'warns and returns nil when the storage root cannot be found' do
      allow(StorageManager.instance).to receive(:root_set)
        .and_return(double('root_set', at: nil))
      allow(Rails.logger).to receive(:warn)

      expect(report.current_root).to be_nil
      expect(Rails.logger).to have_received(:warn).with(/Unable to find storage root/)
    end
  end

  describe '#status' do
    it 'returns PENDING when current_root is nil' do
      allow(StorageManager.instance).to receive(:root_set)
        .and_return(double('root_set', at: nil))
      allow(Rails.logger).to receive(:warn)

      expect(report.status).to eq(Databank::ReportStatus::PENDING)
    end

    it 'returns AVAILABLE when the file exists on storage' do
      allow(storage_root).to receive(:exist?).with(report.storage_key).and_return(true)
      expect(report.status).to eq(Databank::ReportStatus::AVAILABLE)
    end

    it 'returns GENERATING when the file does not exist and report was created over an hour ago' do
      allow(storage_root).to receive(:exist?).and_return(false)
      report.created_at = 2.hours.ago
      expect(report.status).to eq(Databank::ReportStatus::GENERATING)
    end

    it 'returns PENDING when the file does not exist and report was created recently' do
      allow(storage_root).to receive(:exist?).and_return(false)
      report.created_at = 5.minutes.ago
      expect(report.status).to eq(Databank::ReportStatus::PENDING)
    end
  end

  describe '#status_label_class' do
    it 'returns label-success for AVAILABLE status' do
      allow(report).to receive(:status).and_return(Databank::ReportStatus::AVAILABLE)
      expect(report.status_label_class).to eq('label-success')
    end

    it 'returns label-warning for GENERATING status' do
      allow(report).to receive(:status).and_return(Databank::ReportStatus::GENERATING)
      expect(report.status_label_class).to eq('label-warning')
    end

    it 'returns label-default for PENDING status' do
      allow(report).to receive(:status).and_return(Databank::ReportStatus::PENDING)
      expect(report.status_label_class).to eq('label-default')
    end
  end

  describe '#download_object' do
    it 'raises when the storage root is not s3 type' do
      allow(StorageManager.instance).to receive(:root_set)
        .and_return(double('root_set', at: double('fs_root', root_type: :filesystem)))
      expect { report.download_object }.to raise_error(RuntimeError, /invalid root type/)
    end

    it 'returns the S3 object for the report key' do
      aws_client = double('aws_client')
      s3_object  = double('s3_object')
      stub_const('Application', double(aws_client: aws_client))
      allow(aws_client).to receive(:get_object)
        .with(bucket: 'report-bucket', key: "reports/#{report.storage_key}")
        .and_return(s3_object)

      expect(report.download_object).to eq(s3_object)
    end
  end

  describe '#download_path' do
    it 'raises when the storage root is not filesystem type' do
      expect { report.download_path }.to raise_error(RuntimeError, /invalid root type/)
    end

    it 'returns a tmp path for filesystem roots' do
      allow(StorageManager.instance).to receive(:root_set)
        .and_return(double('root_set', at: double('fs_root', root_type: :filesystem)))
      expect(report.download_path).to include("curator_report_#{report.id}.csv")
    end
  end

  describe '#destroy_report_file' do
    it 'warns and returns nil when current_root is nil' do
      allow(StorageManager.instance).to receive(:root_set)
        .and_return(double('root_set', at: nil))
      allow(Rails.logger).to receive(:warn)

      expect(report.destroy_report_file).to be_nil
      expect(Rails.logger).to have_received(:warn).with(/Unable to destroy report file/)
    end

    it 'deletes the report file and info file when they exist' do
      allow(storage_root).to receive(:exist?).with(report.storage_key).and_return(true)
      allow(storage_root).to receive(:exist?).with("#{report.storage_key}.info").and_return(true)
      expect(storage_root).to receive(:delete_content).with(report.storage_key)
      expect(storage_root).to receive(:delete_content).with("#{report.storage_key}.info")

      report.destroy_report_file
    end

    it 'skips deletion when neither file exists' do
      allow(storage_root).to receive(:exist?).and_return(false)
      expect(storage_root).not_to receive(:delete_content)

      report.destroy_report_file
    end
  end

  describe '.generate_report' do
    it 'raises for unknown report types' do
      bad_report = CuratorReport.new(report_type: 'unknown_type')
      expect { CuratorReport.generate_report(bad_report) }
        .to raise_error(RuntimeError, /Unknown report type/)
    end

    it 'delegates FILE_AUDIT type to generate_file_audit_report' do
      expect(CuratorReport).to receive(:generate_file_audit_report).with(report)
      CuratorReport.generate_report(report)
    end
  end

  describe '.generate_file_audit_report' do
    it 'builds a CSV and writes it to the storage root' do
      dataset  = create(:dataset, title: 'Test Dataset', publication_state: 'draft')
      datafile = create(:datafile, dataset: dataset, binary_name: 'data.csv', binary_size: 512)

      allow(datafile).to receive(:exists_on_storage?).and_return(true)
      allow(Dataset).to receive(:find_each).and_yield(dataset)
      allow(dataset).to receive(:datafiles).and_return([datafile])
      expect(storage_root).to receive(:copy_io_to)
        .with(report.storage_key, anything, nil, anything)

      CuratorReport.generate_file_audit_report(report)
    end
  end

  describe '.default_storage_root' do
    it 'returns the name of the report root from StorageManager' do
      allow(StorageManager.instance).to receive(:report_root)
        .and_return(double(name: 'report-root'))
      expect(CuratorReport.default_storage_root).to eq('report-root')
    end
  end

  describe '#download_link' do
    it 'returns a URL path for the report download' do
      expect(report.download_link).to include("/curator_reports/#{report.id}/download")
    end
  end
end
