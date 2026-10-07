require 'rails_helper'

RSpec.describe DatabankMailer, type: :mailer do
  let(:unique_suffix) { SecureRandom.hex(4) }

  let(:dataset) do
    create(
      :dataset,
      key: "TESTIDB-MAILER-#{unique_suffix}",
      depositor_name: 'Depositor Example',
      depositor_email: 'depositor@example.org',
      corresponding_creator_name: 'Contact Creator',
      identifier: "10.13012/B2IDB-MAILER-#{unique_suffix}_V1",
      release_date: Date.new(2026, 1, 1)
    )
  end

  let(:dataset_key) { dataset.key }

  describe '#notify_version_copy_complete' do
    it 'emails curator contact when copy finishes' do
      mail = described_class.notify_version_copy_complete(dataset_key: dataset_key)

      expect(mail.to).to eq([IDB_CONFIG[:admin][:contact_email]])
      expect(mail.subject).to include('Version Copy Complete')
    end
  end

  describe '#contact_help' do
    let(:consultation_params) do
      {
        'help-email' => 'requestor@example.org',
        'help-topic' => 'Dataset Consultation'
      }
    end

    it 'sends consultation request to support contacts and requestor' do
      mail = described_class.contact_help(consultation_params)

      expect(mail.from).to eq([IDB_CONFIG[:admin][:contact_email]])
      expect(mail.to).to contain_exactly(
        IDB_CONFIG[:admin][:contact_email],
        IDB_CONFIG[:admin][:temp_contact_email],
        'requestor@example.org'
      )
      expect(mail.subject).to include('Dataset Consultation Request')
    end

    it 'logs and returns nil for invalid requester email' do
      bad_params = {
        'help-email' => 'not-an-email',
        'help-topic' => 'General'
      }
      null_mail_class = ActionMailer::Base::NullMail

      expect(Rails.logger).to receive(:warn).with('invalid email request from: not-an-email')
      expect(described_class.contact_help(bad_params).message).to be_a(null_mail_class)
    end
  end

  describe '#error' do
    it 'sends a system error email to tech list' do
      mail = described_class.error('example stack trace')

      expect(mail.to).to eq([IDB_CONFIG[:admin][:tech_mail_list].to_s])
      expect(mail.subject).to include('System Error')
    end
  end

  describe '#confirmation_not_sent' do
    it 'emails curator contacts when dataset exists' do
      err = StandardError.new('smtp timeout')
      mail = described_class.confirmation_not_sent(dataset_key, err)

      expect(mail.to).to contain_exactly(
        IDB_CONFIG[:admin][:contact_email],
        IDB_CONFIG[:admin][:temp_contact_email]
      )
      expect(mail.subject).to include('Dataset confirmation email not sent')
    end

    it 'logs and returns null mail when dataset cannot be found' do
      allow(Dataset).to receive(:find_by).with(key: dataset_key).and_return(nil)
      null_mail_class = ActionMailer::Base::NullMail

      expect(Rails.logger).to receive(:warn).with("Confirmation email not sent email not sent because dataset not found for key: #{dataset_key}.")
      expect(described_class.confirmation_not_sent(dataset_key, 'smtp timeout').message).to be_a(null_mail_class)
    end
  end

  describe '#curator_report' do
    it 'emails report requestor with report-specific subject' do
      report = instance_double('CuratorReport', report_type: 'Audit', requestor_email: 'requestor@example.org')
      allow_any_instance_of(DatabankMailer).to receive(:render).and_return('rendered report')

      mail = described_class.curator_report(report)

      expect(mail.to).to eq(['requestor@example.org'])
      expect(mail.subject).to include('Audit Report')
    end
  end

  describe '#missing_ticket' do
    it 'emails curator contact when a ticket is missing' do
      mail = described_class.missing_ticket(dataset_key: dataset_key, note: 'Ticket ID missing')

      expect(mail.to).to eq([IDB_CONFIG[:admin][:contact_email]])
      expect(mail.subject).to include('Missing Ticket for Dataset')
      expect(mail.body.encoded).to include('Ticket ID missing')
    end
  end

  describe '#prepend_system_code' do
    it 'prepends LOCAL prefix when root url includes localhost' do
      config = IDB_CONFIG.deep_dup
      config[:root_url_text] = 'http://localhost:3000'
      stub_const('IDB_CONFIG', config)

      expect(described_class.new.prepend_system_code('Illinois Data Bank] Test Subject')).to start_with('[LOCAL: ')
    end

    it 'prepends DEMO prefix when root url includes demo' do
      config = IDB_CONFIG.deep_dup
      config[:root_url_text] = 'https://demo.databank.illinois.edu'
      stub_const('IDB_CONFIG', config)

      expect(described_class.new.prepend_system_code('Illinois Data Bank] Test Subject')).to start_with('[DEMO: ')
    end

    it 'prepends generic prefix for non-local non-demo roots' do
      config = IDB_CONFIG.deep_dup
      config[:root_url_text] = 'https://databank.illinois.edu'
      stub_const('IDB_CONFIG', config)

      expect(described_class.new.prepend_system_code('Illinois Data Bank] Test Subject')).to start_with('[Illinois Data Bank] Test Subject')
    end
  end

end
