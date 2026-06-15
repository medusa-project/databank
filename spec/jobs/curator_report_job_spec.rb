require 'rails_helper'

RSpec.describe CuratorReportJob, type: :job do
  let(:report) { FactoryBot.create(:curator_report) }
  let(:job) { CuratorReportJob.new(report) }
  let(:delayed_job) { instance_double(Delayed::Job) }

  describe '#initialize' do
    it 'accepts a report and stores it' do
      expect(job.instance_variable_get(:@report)).to eq(report)
    end
  end

  describe '#perform' do
    it 'calls CuratorReport.generate_report with the report' do
      allow(CuratorReport).to receive(:generate_report)
      job.perform
      expect(CuratorReport).to have_received(:generate_report).with(report)
    end
  end

  describe '#success' do
    context 'in test environment' do
      before { allow(Rails.env).to receive(:test?).and_return(true) }

      it 'logs info message instead of sending email' do
        allow(Rails.logger).to receive(:info)
        job.success(delayed_job)
        expect(Rails.logger).to have_received(:info).with(/CuratorReportJob succeeded/)
      end
    end

    context 'in development environment' do
      before do
        allow(Rails.env).to receive(:test?).and_return(false)
        allow(Rails.env).to receive(:development?).and_return(true)
      end

      it 'logs info message instead of sending email' do
        allow(Rails.logger).to receive(:info)
        job.success(delayed_job)
        expect(Rails.logger).to have_received(:info).with(/CuratorReportJob succeeded/)
      end
    end
  end

  describe '#error' do
    let(:exception) { StandardError.new('Test error') }

    it 'logs error message' do
      allow(Rails.logger).to receive(:error)
      job.error(delayed_job, exception)
      expect(Rails.logger).to have_received(:error).with(/CuratorReportJob failed/)
    end
  end

  describe '#failure' do
    it 'logs permanent failure message' do
      allow(Rails.logger).to receive(:error)
      job.failure(delayed_job)
      expect(Rails.logger).to have_received(:error).with(/CuratorReportJob permanently failed/)
    end
  end
end
