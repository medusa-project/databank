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

  describe '#approve_version' do
    it 'emails depositor and copies curator contact' do
      mail = described_class.approve_version(dataset_key: dataset_key)

      expect(mail.to).to eq(['depositor@example.org'])
      expect(mail.cc).to eq([IDB_CONFIG[:admin][:contact_email]])
      expect(mail.subject).to include('New Version Request Approved')
    end
  end

  describe '#request_version' do
    it 'emails curator contact' do
      mail = described_class.request_version(dataset_key: dataset_key)

      expect(mail.to).to eq([IDB_CONFIG[:admin][:contact_email]])
      expect(mail.subject).to include('Version Request')
    end
  end

  describe '#acknowledge_request_version' do
    it 'emails depositor and copies curator contact' do
      mail = described_class.acknowledge_request_version(dataset_key: dataset_key)

      expect(mail.to).to eq(['depositor@example.org'])
      expect(mail.cc).to eq([IDB_CONFIG[:admin][:contact_email]])
      expect(mail.subject).to include('Version Request Acknowledgement')
    end
  end

  describe '#notify_version_copy_complete' do
    it 'emails curator contact when copy finishes' do
      mail = described_class.notify_version_copy_complete(dataset_key: dataset_key)

      expect(mail.to).to eq([IDB_CONFIG[:admin][:contact_email]])
      expect(mail.subject).to include('Version Copy Complete')
    end
  end

  describe '#confirm_deposit' do
    it 'emails depositor, all creators, and curator contacts' do
      Creator.create!(
        dataset: dataset,
        given_name: 'Creator',
        family_name: 'One',
        email: 'creator1@example.org',
        type_of: Databank::CreatorType::PERSON,
        row_order: 1,
        row_position: 1,
        is_contact: true
      )
      Creator.create!(
        dataset: dataset,
        given_name: 'Creator',
        family_name: 'Two',
        email: 'creator2@example.org',
        type_of: Databank::CreatorType::PERSON,
        row_order: 2,
        row_position: 2,
        is_contact: false
      )

      mail = described_class.confirm_deposit(dataset_key)

      expect(mail.to).to contain_exactly(
        'depositor@example.org',
        'creator1@example.org',
        'creator2@example.org',
        IDB_CONFIG[:admin][:contact_email],
        IDB_CONFIG[:admin][:temp_contact_email]
      )
      expect(mail.subject).to include('Dataset deposited')
      expect(mail.subject).to include(dataset.identifier)
    end

    it 'logs and returns nil when dataset cannot be found' do
      allow(Dataset).to receive(:find_by).with(key: dataset_key).and_return(nil)
      null_mail_class = ActionMailer::Base::NullMail

      expect(Rails.logger).to receive(:warn).with("Confirmation email not sent: #{dataset_key}.")
      expect(described_class.confirm_deposit(dataset_key).message).to be_a(null_mail_class)
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

  describe '#confirm_deposit_update' do
    it 'emails curator contacts when dataset exists' do
      mail = described_class.confirm_deposit_update(dataset_key)

      expect(mail.to).to contain_exactly(
        IDB_CONFIG[:admin][:contact_email],
        IDB_CONFIG[:admin][:temp_contact_email]
      )
      expect(mail.subject).to include('Dataset updated')
      expect(mail.subject).to include(dataset.identifier)
    end

    it 'logs and returns null mail when dataset cannot be found' do
      allow(Dataset).to receive(:find_by).with(key: dataset_key).and_return(nil)
      null_mail_class = ActionMailer::Base::NullMail

      expect(Rails.logger).to receive(:warn).with("Update confirmation email not sent: #{dataset_key}.")
      expect(described_class.confirm_deposit_update(dataset_key).message).to be_a(null_mail_class)
    end
  end

  describe '#dataset_incomplete_1m' do
    it 'emails depositor and cc curator contacts when dataset exists' do
      allow_any_instance_of(DatabankMailer).to receive(:render).and_return('rendered incomplete dataset notice')

      mail = described_class.dataset_incomplete_1m(dataset_key)

      expect(mail.to).to eq(['depositor@example.org'])
      expect(mail.cc).to contain_exactly(
        IDB_CONFIG[:admin][:contact_email],
        IDB_CONFIG[:admin][:temp_contact_email]
      )
      expect(mail.subject).to include('Incomplete dataset deposit')
    end

    it 'logs and returns null mail when dataset cannot be found' do
      allow(Dataset).to receive(:find_by).with(key: dataset_key).and_return(nil)
      null_mail_class = ActionMailer::Base::NullMail

      expect(Rails.logger).to receive(:warn).with("Dataset incomplete 1m email not sent: #{dataset_key}.")
      expect(described_class.dataset_incomplete_1m(dataset_key).message).to be_a(null_mail_class)
    end
  end

  describe '#embargo_approaching_1m' do
    it 'emails depositor and cc curator contacts when dataset exists' do
      mail = described_class.embargo_approaching_1m(dataset_key)

      expect(mail.to).to eq(['depositor@example.org'])
      expect(mail.cc).to contain_exactly(
        IDB_CONFIG[:admin][:contact_email],
        IDB_CONFIG[:admin][:temp_contact_email]
      )
      expect(mail.subject).to include('Dataset release date approaching')
    end

    it 'logs and returns null mail when dataset cannot be found' do
      allow(Dataset).to receive(:find_by).with(key: dataset_key).and_return(nil)
      null_mail_class = ActionMailer::Base::NullMail

      expect(Rails.logger).to receive(:warn).with("Embargo 1m email not sent: #{dataset_key}.")
      expect(described_class.embargo_approaching_1m(dataset_key).message).to be_a(null_mail_class)
    end
  end

  describe '#embargo_approaching_1w' do
    it 'emails depositor and cc curator contacts when dataset exists' do
      mail = described_class.embargo_approaching_1w(dataset_key)

      expect(mail.to).to eq(['depositor@example.org'])
      expect(mail.cc).to contain_exactly(
        IDB_CONFIG[:admin][:contact_email],
        IDB_CONFIG[:admin][:temp_contact_email]
      )
      expect(mail.subject).to include('Dataset release date approaching')
    end

    it 'logs and returns null mail when dataset cannot be found' do
      allow(Dataset).to receive(:find_by).with(key: dataset_key).and_return(nil)
      null_mail_class = ActionMailer::Base::NullMail

      expect(Rails.logger).to receive(:warn).with("Embargo 1w email not sent: #{dataset_key}.")
      expect(described_class.embargo_approaching_1w(dataset_key).message).to be_a(null_mail_class)
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

  describe '#prepub_filechange' do
    it 'emails curator contact for file changes under review' do
      datafile = create(:datafile, dataset: dataset)

      mail = described_class.prepub_filechange(datafile.web_id, 'deleted')

      expect(mail.to).to eq([IDB_CONFIG[:admin][:contact_email]])
      expect(mail.subject).to include('File change in dataset under pre-publication review')
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
