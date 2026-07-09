require 'rails_helper'
require 'tmpdir'
require 'csv'

RSpec.describe Metric, type: :model do
  before do
    allow(Sunspot).to receive(:remove_all!)
    allow(Sunspot).to receive(:index)
    allow(Sunspot).to receive(:index!)
    allow(Sunspot).to receive(:commit)
  end

  def metrics_config_for(dir)
    {
      dataset_downloads_json: { relative_path: File.join(dir, 'dataset_downloads.json') },
      datafile_downloads_json: { relative_path: File.join(dir, 'datafile_downloads.json') },
      datafiles_csv: { relative_path: File.join(dir, 'datafiles.csv') },
      datasets_tsv: { relative_path: File.join(dir, 'datasets.tsv') },
      container_contents_csv: { relative_path: File.join(dir, 'container_contents.csv') },
      funders_csv: { relative_path: File.join(dir, 'funders.csv') },
      related_materials_csv: { relative_path: File.join(dir, 'related_materials.csv') },
      dataset_report_csv: { relative_path: File.join(dir, 'dataset_report.csv') },
      dataset_report_text: { relative_path: File.join(dir, 'dataset_report.txt') }
    }
  end

  describe '.refresh_all' do
    it 'invokes each metrics writer once' do
      expect(Metric).to receive(:write_dataset_downloads_json).once
      expect(Metric).to receive(:write_datafile_downloads_json).once
      expect(Metric).to receive(:write_datafiles_csv).once
      expect(Metric).to receive(:write_datasets_tsv).once
      expect(Metric).to receive(:write_container_contents_csv).once
      expect(Metric).to receive(:write_funders_csv).once
      expect(Metric).to receive(:write_related_materials_csv).once

      Metric.refresh_all
    end
  end

  describe '.modified_times' do
    it 'returns formatted modified timestamps when all files exist' do
      Dir.mktmpdir('metric-modified-times') do |dir|
        stub_const('METRICS_CONFIG', metrics_config_for(dir))

        METRICS_CONFIG.each_value do |v|
          File.write(v[:relative_path], 'x')
        end

        allow(Metric).to receive(:sleep)
        result = Metric.modified_times

        expect(result).to include(:dataset_downloads_json,
                                  :datafile_downloads_json,
                                  :datafiles_csv,
                                  :datasets_tsv,
                                  :container_contents_csv,
                                  :funders_csv,
                                  :related_materials_csv)
        expect(result[:dataset_downloads_json]).to be_a(String)
      end
    end

    it 'raises when dataset downloads json cannot be created' do
      Dir.mktmpdir('metric-modified-times-fail') do |dir|
        stub_const('METRICS_CONFIG', metrics_config_for(dir))
        downloads_path = METRICS_CONFIG[:dataset_downloads_json][:relative_path]

        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(downloads_path).and_return(false)
        allow(Metric).to receive(:write_dataset_downloads_json)

        expect { Metric.modified_times }
          .to raise_error(StandardError, /unable to create dataset downloads json/)
      end
    end
  end

  describe '.write_datafile_csv_datafile_batch' do
    it 'appends rows through the provided CSV writer and falls back to the default mimetype' do
      Dir.mktmpdir('metric-datafile-csv') do |dir|
        target_path = File.join(dir, 'datafiles.csv')
        File.write(target_path, "doi,pub_date,filename,file_format,num_bytes,total_downloads\n")

        dataset = double(
          identifier: '10.13012/B2IDB-ABC_V1',
          release_date: Date.new(2026, 5, 4)
        )
        datafile1 = double(medusa_path: 'path/to/FileA.TXT', bytestream_name: 'FileA.TXT', bytestream_size: 123, total_downloads: 8)
        datafile2 = double(medusa_path: 'path/to/FileB.bin', bytestream_name: 'FileB.bin', bytestream_size: 321, total_downloads: 2)
        manifest = {
          'records' => [
            { 'cfs_file_relative_path' => 'path/to/FileA.TXT', 'content_type_name' => 'text/plain' }
          ]
        }

        CSV.open(target_path, 'a') do |report|
          Metric.write_datafile_csv_datafile_batch(report, dataset, [datafile1, datafile2], manifest)
        end

        rows = CSV.read(target_path)
        expect(rows.length).to eq(3)
        expect(rows[1]).to eq(['10.13012/B2IDB-ABC_V1', '2026-05-04', 'FileA.TXT', 'text/plain', '123', '8'])
        expect(rows[2]).to eq(['10.13012/B2IDB-ABC_V1', '2026-05-04', 'FileB.bin', Metric::MIMETYPE_DEFAULT, '321', '2'])
      end
    end

    it 'returns early for an empty batch' do
      report = instance_double(CSV)
      dataset = double(identifier: '10.13012/B2IDB-ABC_V1', release_date: Date.new(2026, 5, 4))

      expect(MedusaInfo).not_to receive(:mimetype_batch)
      expect(report).not_to receive(:<<)

      Metric.write_datafile_csv_datafile_batch(report, dataset, [], { 'records' => [] })
    end
  end

  describe '.write_related_materials_csv' do
    it 'excludes version relationships and writes non-version rows' do
      Dir.mktmpdir('metric-related-materials') do |dir|
        stub_const('METRICS_CONFIG', metrics_config_for(dir))
        target_path = METRICS_CONFIG[:related_materials_csv][:relative_path]

        material = double(
          datacite_list: 'IsCitedBy,IsPreviousVersionOf,IsNewVersionOf',
          uri_type: 'DOI',
          uri: '10.9999/example',
          selected_type: 'JournalArticle'
        )
        dataset = double(identifier: '10.13012/B2IDB-XYZ_V1', related_materials: [material], metadata_public?: true)
        expect(Dataset).to receive(:find_each).with(batch_size: 500).and_yield(dataset)

        Metric.write_related_materials_csv

        rows = CSV.read(target_path)
        expect(rows.length).to eq(2)
        expect(rows[1]).to eq(['10.13012/B2IDB-XYZ_V1', 'IsCitedBy', 'DOI', '10.9999/example', 'JournalArticle'])
      end
    end
  end

  describe '.write_dataset_downloads_json' do
    it 'writes dataset download rows and totals csv' do
      Dir.mktmpdir('metric-dataset-downloads') do |dir|
        stub_const('METRICS_CONFIG', metrics_config_for(dir))
        target_path = METRICS_CONFIG[:dataset_downloads_json][:relative_path]
        dataset = create(:dataset)

        create(:dataset_download_tally, dataset_key: dataset.key, doi: '10.13012/B2IDB-AAA_V1', tally: 2, download_date: Date.new(2026, 5, 1))
        create(:dataset_download_tally, dataset_key: dataset.key, doi: '10.13012/B2IDB-AAA_V1', tally: 3, download_date: Date.new(2026, 5, 2))

        Metric.write_dataset_downloads_json

        json = JSON.parse(File.read(target_path))
        expect(json['dataset_downloads'].length).to eq(2)

        totals_path = target_path.split('.json').first + '_totals.csv'
        totals_rows = CSV.read(totals_path)
        expect(totals_rows).to include(['doi', 'tally'])
        expect(totals_rows).to include(['10.13012/B2IDB-AAA_V1', '5'])
      end
    end

    it 'does not replace published files when generation fails' do
      Dir.mktmpdir('metric-dataset-downloads-failure') do |dir|
        stub_const('METRICS_CONFIG', metrics_config_for(dir))
        target_path = METRICS_CONFIG[:dataset_downloads_json][:relative_path]
        totals_path = target_path.split('.json').first + '_totals.csv'
        File.write(target_path, "old json\n")
        File.write(totals_path, "old totals\n")

        allow(DatasetDownloadTally).to receive(:find_in_batches).with(batch_size: 500).and_raise(StandardError, 'boom')

        expect { Metric.write_dataset_downloads_json }.to raise_error(StandardError, 'boom')
        expect(File.read(target_path)).to eq("old json\n")
        expect(File.read(totals_path)).to eq("old totals\n")
      end
    end
  end

  describe '.write_datafile_downloads_json' do
    it 'writes file download tally rows to json' do
      Dir.mktmpdir('metric-datafile-downloads') do |dir|
        stub_const('METRICS_CONFIG', metrics_config_for(dir))
        target_path = METRICS_CONFIG[:datafile_downloads_json][:relative_path]

        create(:file_download_tally,
               doi: '10.13012/B2IDB-AAA_V1',
               filename: 'sample.csv',
               download_date: Date.new(2026, 5, 3),
               tally: 7)

        Metric.write_datafile_downloads_json

        json = JSON.parse(File.read(target_path))
        expect(json['datafile_downloads'].length).to eq(1)
        expect(json['datafile_downloads'][0]['file']).to eq('sample.csv')
        expect(json['datafile_downloads'][0]['tally']).to eq(7)
      end
    end

    it 'does not replace the published json when generation fails' do
      Dir.mktmpdir('metric-datafile-downloads-failure') do |dir|
        stub_const('METRICS_CONFIG', metrics_config_for(dir))
        target_path = METRICS_CONFIG[:datafile_downloads_json][:relative_path]
        File.write(target_path, "old json\n")

        allow(FileDownloadTally).to receive(:find_in_batches).with(batch_size: 500).and_raise(StandardError, 'boom')

        expect { Metric.write_datafile_downloads_json }.to raise_error(StandardError, 'boom')
        expect(File.read(target_path)).to eq("old json\n")
      end
    end
  end

  describe '.write_datasets_tsv' do
    it 'writes heading and one row per public dataset' do
      Dir.mktmpdir('metric-datasets-tsv') do |dir|
        stub_const('METRICS_CONFIG', metrics_config_for(dir))
        target_path = METRICS_CONFIG[:datasets_tsv][:relative_path]

        dataset = instance_double(
          Dataset,
          metadata_public?: true,
          identifier: '10.13012/B2IDB-XYZ_V1',
          ingest_datetime: Time.zone.parse('2026-05-01 12:00:00'),
          release_date: Date.new(2026, 5, 2),
          datafiles: [double, double],
          total_filesize: 1234,
          total_downloads: 88,
          num_external_relationships: 3,
          creators: [double, double],
          subject: 'Physical Sciences',
          plain_text_citation: 'Citation text'
        )
        allow(dataset).to receive(:handle_related_materials)
        expect(Dataset).to receive(:find_each).with(batch_size: 500).and_yield(dataset)

        Metric.write_datasets_tsv

        rows = File.read(target_path).lines.map(&:strip)
        expect(rows.first).to include('doi')
        expect(rows[1]).to include('10.13012/B2IDB-XYZ_V1')
        expect(rows[1]).to include('Citation text')
      end
    end
  end

  describe '.write_datafiles_csv' do
    it 'processes dataset datafiles through relation batches and publishes the completed CSV atomically' do
      Dir.mktmpdir('metric-write-datafiles-csv') do |dir|
        stub_const('METRICS_CONFIG', metrics_config_for(dir))
        target_path = METRICS_CONFIG[:datafiles_csv][:relative_path]
        File.write(target_path, "old contents\n")

        datafile_relation = instance_double(ActiveRecord::Relation)
        datafile1 = instance_double(Datafile,
                                    medusa_path: 'path/to/file-1.csv',
                                    bytestream_name: 'file-1.csv',
                                    bytestream_size: 10,
                                    total_downloads: 2)
        datafile2 = instance_double(Datafile,
                                    medusa_path: 'path/to/file-2.csv',
                                    bytestream_name: 'file-2.csv',
                                    bytestream_size: 20,
                                    total_downloads: 4)
        dataset = instance_double(Dataset,
                                  identifier: '10.13012/B2IDB-ABC_V1',
                                  release_date: Date.new(2026, 5, 4),
                                  metadata_public?: true,
                                  datafiles: datafile_relation)
        expect(Dataset).to receive(:find_each).with(batch_size: 500).and_yield(dataset)
        allow(datafile_relation).to receive(:reorder).with(nil).and_return(datafile_relation)
        expect(datafile_relation).to receive(:find_in_batches).with(batch_size: 500).and_yield([datafile1]).and_yield([datafile2])
        allow(MedusaInfo).to receive(:content_type_manifest).and_return(
          'records' => [
            { 'cfs_file_relative_path' => 'path/to/file-1.csv', 'content_type_name' => 'text/csv' },
            { 'cfs_file_relative_path' => 'path/to/file-2.csv', 'content_type_name' => 'text/plain' }
          ]
        )
        allow(Metric).to receive(:write_datafile_csv_datafile_batch).and_wrap_original do |original, report, *args|
          expect(File.read(target_path)).to eq("old contents\n")
          original.call(report, *args)
        end

        Metric.write_datafiles_csv

        expect(Metric).to have_received(:write_datafile_csv_datafile_batch).twice
        rows = CSV.read(target_path)
        expect(rows).to eq([
          ['doi', 'pub_date', 'filename', 'file_format', 'num_bytes', 'total_downloads'],
          ['10.13012/B2IDB-ABC_V1', '2026-05-04', 'file-1.csv', 'text/csv', '10', '2'],
          ['10.13012/B2IDB-ABC_V1', '2026-05-04', 'file-2.csv', 'text/plain', '20', '4']
        ])
      end
    end

    it 'does not replace the published CSV when generation fails' do
      Dir.mktmpdir('metric-write-datafiles-csv-failure') do |dir|
        stub_const('METRICS_CONFIG', metrics_config_for(dir))
        target_path = METRICS_CONFIG[:datafiles_csv][:relative_path]
        File.write(target_path, "old contents\n")

        datafile_relation = instance_double(ActiveRecord::Relation)
        dataset = instance_double(Dataset, metadata_public?: true, datafiles: datafile_relation)
        expect(Dataset).to receive(:find_each).with(batch_size: 500).and_yield(dataset)
        allow(datafile_relation).to receive(:reorder).with(nil).and_return(datafile_relation)
        allow(datafile_relation).to receive(:find_in_batches).with(batch_size: 500).and_yield([instance_double(Datafile)])
        allow(MedusaInfo).to receive(:content_type_manifest).and_return('records' => [{}])
        allow(Metric).to receive(:write_datafile_csv_datafile_batch).and_raise(StandardError, 'boom')

        expect { Metric.write_datafiles_csv }.to raise_error(StandardError, 'boom')
        expect(File.read(target_path)).to eq("old contents\n")
        expect(Dir.glob(File.join(dir, 'datafiles*.csv'))).to eq([target_path])
      end
    end

    it 'logs and exits without publishing when the content type manifest is invalid' do
      Dir.mktmpdir('metric-write-datafiles-csv-invalid-manifest') do |dir|
        stub_const('METRICS_CONFIG', metrics_config_for(dir))
        target_path = METRICS_CONFIG[:datafiles_csv][:relative_path]
        lock_path = Metric.lock_path(:datafiles_csv)
        logger = instance_double(ActiveSupport::Logger)
        File.write(target_path, "old contents\n")

        allow(MedusaInfo).to receive(:content_type_manifest).and_return(nil)
        allow(Rails).to receive(:logger).and_return(logger)
        expect(logger).to receive(:error).with('Unable to write datafiles csv: content type manifest is missing or invalid')
        expect(Dataset).not_to receive(:find_each)
        expect(Metric).not_to receive(:write_metric_files_atomically)

        Metric.write_datafiles_csv

        expect(File.read(target_path)).to eq("old contents\n")
        expect(File).not_to exist(lock_path)
        expect(Dir.glob(File.join(dir, 'datafiles*.csv'))).to eq([target_path])
      end
    end

    it 'clears the lock when content type manifest loading raises' do
      Dir.mktmpdir('metric-write-datafiles-csv-manifest-error') do |dir|
        stub_const('METRICS_CONFIG', metrics_config_for(dir))
        target_path = METRICS_CONFIG[:datafiles_csv][:relative_path]
        lock_path = Metric.lock_path(:datafiles_csv)
        File.write(target_path, "old contents\n")

        allow(MedusaInfo).to receive(:content_type_manifest).and_raise(StandardError, 'boom')

        expect { Metric.write_datafiles_csv }.to raise_error(StandardError, 'boom')
        expect(File.read(target_path)).to eq("old contents\n")
        expect(File).not_to exist(lock_path)
        expect(Dir.glob(File.join(dir, 'datafiles*.csv'))).to eq([target_path])
      end
    end
  end

  describe '.write_container_contents_csv' do
    it 'writes nested item rows only for archive datafiles from batched relations' do
      Dir.mktmpdir('metric-container-contents-csv') do |dir|
        stub_const('METRICS_CONFIG', metrics_config_for(dir))
        target_path = METRICS_CONFIG[:container_contents_csv][:relative_path]

        datafile_relation = instance_double(ActiveRecord::Relation)
        archive_relation = instance_double(ActiveRecord::Relation)
        nested_item = instance_double(NestedItem, item_path: 'folder/a.txt', item_name: 'a.txt', media_type: 'text/plain')
        archive_datafile = instance_double(Datafile, bytestream_name: 'files.zip', nested_items: [nested_item])
        dataset = instance_double(Dataset, identifier: '10.13012/B2IDB-CONT_V1', metadata_public?: true, datafiles: datafile_relation)
        expect(Dataset).to receive(:find_each).with(batch_size: 500).and_yield(dataset)
        allow(datafile_relation).to receive(:where).with(peek_type: Databank::PeekType::LISTING).and_return(archive_relation)
        allow(archive_relation).to receive(:includes).with(:nested_items).and_return(archive_relation)
        allow(archive_relation).to receive(:reorder).with(nil).and_return(archive_relation)
        expect(archive_relation).to receive(:find_each).with(batch_size: 500).and_yield(archive_datafile)

        Metric.write_container_contents_csv

        rows = CSV.read(target_path)
        expect(rows.length).to eq(2)
        expect(rows[1]).to eq(['10.13012/B2IDB-CONT_V1', 'files.zip', 'folder/a.txt', 'a.txt', 'text/plain'])
      end
    end
  end

  describe '.write_funders_csv' do
    it 'writes one row per dataset funder' do
      Dir.mktmpdir('metric-funders-csv') do |dir|
        stub_const('METRICS_CONFIG', metrics_config_for(dir))
        target_path = METRICS_CONFIG[:funders_csv][:relative_path]

        dataset = create(:dataset, identifier: '10.13012/B2IDB-FUND_V1')
        funder = create(:funder, dataset: dataset, name: 'NSF', grant: 'NSF-42')
        expect(Dataset).to receive(:find_each).with(batch_size: 500).and_yield(dataset)
        allow(dataset).to receive(:metadata_public?).and_return(true)

        Metric.write_funders_csv

        rows = CSV.read(target_path)
        expect(rows).to include(['doi', 'funder', 'grant'])
        expect(rows).to include(['10.13012/B2IDB-FUND_V1', funder.name, funder.grant])
      end
    end
  end

  describe '.generate_datasets_reports' do
    it 'writes CSV and text entries only for public most-recent datasets' do
      Dir.mktmpdir('metric-generate-reports') do |dir|
        stub_const('METRICS_CONFIG', metrics_config_for(dir))
        csv_path = METRICS_CONFIG[:dataset_report_csv][:relative_path]
        text_path = METRICS_CONFIG[:dataset_report_text][:relative_path]

        visible_dataset = instance_double(
          Dataset,
          metadata_public?: true,
          is_most_recent_version: true,
          key: 'IDB-ABC1234',
          identifier: '10.13012/B2IDB-ABC1234_V1',
          release_date: Date.new(2026, 5, 3),
          funders: [instance_double(Funder, name: 'NSF', grant: 'NSF-99')],
          title: 'Visible Dataset',
          keywords: 'alpha; beta',
          corresponding_creator_name: 'Pat Researcher',
          corresponding_creator_email: 'pat@example.org',
          subject: 'Technology and Engineering',
          plain_text_citation: 'Visible citation text',
          description: 'Visible description'
        )
        hidden_dataset = instance_double(Dataset, metadata_public?: false, is_most_recent_version: true)

        expect(Dataset).to receive(:find_each).with(batch_size: 500).and_yield(visible_dataset).and_yield(hidden_dataset)

        Metric.generate_datasets_reports

        csv_rows = CSV.read(csv_path)
        expect(csv_rows.length).to eq(2)
        expect(csv_rows[1]).to include('IDB-ABC1234', '10.13012/B2IDB-ABC1234_V1', 'Visible Dataset')

        text_body = File.read(text_path)
        expect(text_body).to include('Key: IDB-ABC1234')
        expect(text_body).to include('Description: Visible description')
      end
    end

    it 'does not replace published dataset reports when generation fails' do
      Dir.mktmpdir('metric-generate-reports-failure') do |dir|
        stub_const('METRICS_CONFIG', metrics_config_for(dir))
        csv_path = METRICS_CONFIG[:dataset_report_csv][:relative_path]
        text_path = METRICS_CONFIG[:dataset_report_text][:relative_path]
        File.write(csv_path, "old csv\n")
        File.write(text_path, "old text\n")

        expect(Dataset).to receive(:find_each).with(batch_size: 500).and_raise(StandardError, 'boom')

        expect { Metric.generate_datasets_reports }.to raise_error(StandardError, 'boom')
        expect(File.read(csv_path)).to eq("old csv\n")
        expect(File.read(text_path)).to eq("old text\n")
      end
    end
  end
end
