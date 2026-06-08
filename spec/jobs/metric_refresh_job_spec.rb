require 'rails_helper'

RSpec.describe MetricRefreshJob, type: :job do
  describe '#initialize' do
    it 'accepts a metric key and converts to symbol' do
      job = MetricRefreshJob.new('dataset_downloads_json')
      expect(job.instance_variable_get(:@metric_key)).to eq(:dataset_downloads_json)
    end

    it 'handles symbol input' do
      job = MetricRefreshJob.new(:datafile_downloads_json)
      expect(job.instance_variable_get(:@metric_key)).to eq(:datafile_downloads_json)
    end
  end

  describe '#perform' do
    let(:metric_key) { :dataset_downloads_json }
    let(:job) { MetricRefreshJob.new(metric_key) }

    it 'calls the corresponding Metric method' do
      allow(Metric).to receive(:write_dataset_downloads_json)
      job.perform
      expect(Metric).to have_received(:write_dataset_downloads_json)
    end

    it 'raises ArgumentError for unknown metric key' do
      invalid_job = MetricRefreshJob.new(:unknown_metric)
      expect { invalid_job.perform }.to raise_error(ArgumentError, /Unknown metric key/)
    end

    it 'maps all known metric keys correctly' do
      mappings = {
        dataset_downloads_json: :write_dataset_downloads_json,
        datafile_downloads_json: :write_datafile_downloads_json,
        datasets_tsv: :write_datasets_tsv,
        datafiles_csv: :write_datafiles_csv,
        container_contents_csv: :write_container_contents_csv,
        funders_csv: :write_funders_csv,
        related_materials_csv: :write_related_materials_csv
      }

      mappings.each do |key, method|
        job = MetricRefreshJob.new(key)
        allow(Metric).to receive(method)
        job.perform
        expect(Metric).to have_received(method)
      end
    end
  end

  describe '#success' do
    let(:job) { MetricRefreshJob.new(:dataset_downloads_json) }
    let(:delayed_job) { instance_double(Delayed::Job) }

    it 'logs success message' do
      allow(Rails.logger).to receive(:info)
      job.success(delayed_job)
      expect(Rails.logger).to have_received(:info).with(/MetricRefreshJob succeeded/)
    end
  end

  describe '#error' do
    let(:job) { MetricRefreshJob.new(:dataset_downloads_json) }
    let(:delayed_job) { instance_double(Delayed::Job) }
    let(:exception) { StandardError.new('Test error') }

    it 'logs error message' do
      allow(Rails.logger).to receive(:error)
      job.error(delayed_job, exception)
      expect(Rails.logger).to have_received(:error).with(/MetricRefreshJob error/)
    end

    it 'clears the in-progress flag for the metric' do
      allow(Rails.logger).to receive(:error)
      allow(Metric).to receive(:clear_in_progress)
      job.error(delayed_job, exception)
      expect(Metric).to have_received(:clear_in_progress).with(:dataset_downloads_json)
    end
  end

  describe '#failure' do
    let(:job) { MetricRefreshJob.new(:dataset_downloads_json) }
    let(:delayed_job) { instance_double(Delayed::Job) }

    it 'logs permanent failure message' do
      allow(Rails.logger).to receive(:error)
      job.failure(delayed_job)
      expect(Rails.logger).to have_received(:error).with(/MetricRefreshJob permanently failed/)
    end

    it 'clears the in-progress flag for the metric' do
      allow(Rails.logger).to receive(:error)
      allow(Metric).to receive(:clear_in_progress)
      job.failure(delayed_job)
      expect(Metric).to have_received(:clear_in_progress).with(:dataset_downloads_json)
    end
  end
end
