require 'rails_helper'
require 'tmpdir'
require 'csv'

RSpec.describe Metric, type: :model do
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
    it 'appends rows and downcases doi+filename key for mimetype lookups' do
      Dir.mktmpdir('metric-datafile-csv') do |dir|
        target_path = File.join(dir, 'datafiles.csv')
        File.write(target_path, "doi,pub_date,filename,file_format,num_bytes,total_downloads\n")

        dataset = double(
          identifier: '10.13012/B2IDB-ABC_V1',
          release_date: Date.new(2026, 5, 4)
        )
        datafile1 = double(bytestream_name: 'FileA.TXT', bytestream_size: 123, total_downloads: 8)
        datafile2 = double(bytestream_name: 'FileB.bin', bytestream_size: 321, total_downloads: 2)
        map = {
          '10.13012/b2idb-abc_v1_filea.txt' => 'text/plain'
        }

        Metric.write_datafile_csv_datafile_batch(target_path, dataset, [datafile1, datafile2], map)

        rows = CSV.read(target_path)
        expect(rows.length).to eq(3)
        expect(rows[1]).to eq(['10.13012/B2IDB-ABC_V1', '2026-05-04', 'FileA.TXT', 'text/plain', '123', '8'])
        expect(rows[2]).to eq(['10.13012/B2IDB-ABC_V1', '2026-05-04', 'FileB.bin', '', '321', '2'])
      end
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
        dataset = double(identifier: '10.13012/B2IDB-XYZ_V1', related_materials: [material])
        allow(Dataset).to receive(:all_with_public_metadata).and_return([dataset])

        Metric.write_related_materials_csv

        rows = CSV.read(target_path)
        expect(rows.length).to eq(2)
        expect(rows[1]).to eq(['10.13012/B2IDB-XYZ_V1', 'IsCitedBy', 'DOI', '10.9999/example', 'JournalArticle'])
      end
    end
  end
end
