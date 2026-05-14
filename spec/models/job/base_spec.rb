require 'rails_helper'

RSpec.describe Job::Base, type: :model do
  let(:concrete_job_class) do
    Class.new(described_class) do
      self.table_name = 'datasets'
    end
  end
  subject(:job_record) { concrete_job_class.new(id: 123) }

  let(:settings_double) { instance_double('Settings') }
  let(:delayed_job_settings) { instance_double('DelayedJobSettings') }
  let(:priority_settings) { instance_double('PrioritySettings') }
  let(:error_mailer) { class_double('DelayedJobErrorMailer') }

  before do
    stub_const('Settings', settings_double)
    allow(settings_double).to receive(:delayed_job).and_return(delayed_job_settings)
    allow(delayed_job_settings).to receive(:priority).and_return(priority_settings)
    stub_const('DelayedJobErrorMailer', error_mailer)
  end

  describe '#destroy_queued_jobs_and_self' do
    it 'destroys queued jobs before destroying itself' do
      delayed_jobs = [instance_double(Delayed::Job), instance_double(Delayed::Job)]
      allow(job_record).to receive(:destroy_queued_jobs) do
        delayed_jobs.each(&:destroy)
      end
      allow(job_record).to receive(:destroy)
      delayed_jobs.each { |job| allow(job).to receive(:destroy) }

      job_record.destroy_queued_jobs_and_self

      delayed_jobs.each { |job| expect(job).to have_received(:destroy) }
      expect(job_record).to have_received(:destroy)
    end
  end

  describe '#destroy_queued_jobs' do
    it 'destroys each matching delayed job' do
      delayed_jobs = [instance_double(Delayed::Job), instance_double(Delayed::Job)]
      allow(job_record).to receive(:delayed_jobs).and_return(delayed_jobs)
      delayed_jobs.each { |job| allow(job).to receive(:destroy) }

      job_record.destroy_queued_jobs

      delayed_jobs.each { |job| expect(job).to have_received(:destroy) }
    end
  end

  describe '#delayed_jobs' do
    it 'returns only delayed jobs whose handler deserializes to self' do
      matching_job = instance_double(Delayed::Job, handler: 'matching-yaml')
      other_job = instance_double(Delayed::Job, handler: 'other-yaml')
      allow(Delayed::Job).to receive(:all).and_return([matching_job, other_job])
      allow(YAML).to receive(:safe_load).with('matching-yaml').and_return(job_record)
      allow(YAML).to receive(:safe_load).with('other-yaml').and_return(concrete_job_class.new(id: 999))

      expect(job_record.delayed_jobs).to eq([matching_job])
    end
  end

  describe '#success' do
    it 'destroys itself' do
      allow(job_record).to receive(:destroy!)

      job_record.success(nil)

      expect(job_record).to have_received(:destroy!)
    end
  end

  describe '#error' do
    it 'delegates to notify_on_error with the exception' do
      delayed_job = instance_double(Delayed::Job)
      exception = StandardError.new('boom')
      allow(job_record).to receive(:notify_on_error)

      job_record.error(delayed_job, exception)

      expect(job_record).to have_received(:notify_on_error).with(delayed_job, exception)
    end
  end

  describe '#failure' do
    it 'delegates to notify_on_error without an exception' do
      delayed_job = instance_double(Delayed::Job)
      allow(job_record).to receive(:notify_on_error)

      job_record.failure(delayed_job)

      expect(job_record).to have_received(:notify_on_error).with(delayed_job, nil)
    end
  end

  describe '#notify_on_error' do
    let(:mailer_delivery) { instance_double(ActionMailer::MessageDelivery, deliver_now: true) }

    it 'sends an error email when attempts are at least five' do
      delayed_job = instance_double(Delayed::Job, attempts: 5)
      exception = StandardError.new('boom')
      allow(error_mailer).to receive(:error).with(delayed_job, exception).and_return(mailer_delivery)

      job_record.notify_on_error(delayed_job, exception)

      expect(error_mailer).to have_received(:error).with(delayed_job, exception)
      expect(mailer_delivery).to have_received(:deliver_now)
    end

    it 'does not send an error email before the threshold' do
      delayed_job = instance_double(Delayed::Job, attempts: 4)
      allow(error_mailer).to receive(:error)

      job_record.notify_on_error(delayed_job)

      expect(error_mailer).not_to have_received(:error)
    end
  end

  describe '#reset_delayed_jobs' do
    it 'resets retriable delayed jobs and skips untouched ones' do
      retried_job = instance_double(Delayed::Job, attempts: 2, save!: true)
      untouched_job = instance_double(Delayed::Job, attempts: 0)
      allow(job_record).to receive(:delayed_jobs).and_return([retried_job, untouched_job])
      freeze_time = Time.zone.parse('2026-05-06 12:00:00 UTC')
      allow(Time.zone).to receive(:now).and_return(freeze_time)
      allow(retried_job).to receive(:attempts=)
      allow(retried_job).to receive(:run_at=)
      allow(retried_job).to receive(:locked_at=)
      allow(retried_job).to receive(:locked_by=)
      allow(retried_job).to receive(:last_error=)

      job_record.reset_delayed_jobs

      expect(retried_job).to have_received(:attempts=).with(1)
      expect(retried_job).to have_received(:run_at=).with(freeze_time)
      expect(retried_job).to have_received(:locked_at=).with(nil)
      expect(retried_job).to have_received(:locked_by=).with(nil)
      expect(retried_job).to have_received(:last_error=).with('')
      expect(retried_job).to have_received(:save!)
    end
  end

  describe '#enqueue_job' do
    it 'enqueues itself with merged queue and priority defaults' do
      allow(job_record).to receive(:queue).and_return('default-queue')
      allow(job_record).to receive(:priority).and_return(10)
      allow(Delayed::Job).to receive(:enqueue)

      job_record.enqueue_job(run_at: Time.zone.parse('2026-05-07 00:00:00 UTC'))

      expect(Delayed::Job).to have_received(:enqueue).with(
        job_record,
        hash_including(queue: 'default-queue', priority: 10, run_at: Time.zone.parse('2026-05-07 00:00:00 UTC'))
      )
    end
  end

  describe '#queue' do
    it 'returns the default delayed job queue' do
      allow(delayed_job_settings).to receive(:default_queue).and_return('mailers')

      expect(job_record.queue).to eq('mailers')
    end
  end

  describe '#priority' do
    it 'returns the base job priority' do
      allow(priority_settings).to receive(:base_job).and_return(25)

      expect(job_record.priority).to eq(25)
    end
  end
end
