require 'rails_helper'

RSpec.describe DatabankMailer, type: :mailer do
  let(:dataset) do
    create(
      :dataset,
      key: 'test-dataset-key',
      depositor_name: 'Depositor Example',
      depositor_email: 'depositor@example.org',
      corresponding_creator_name: 'Contact Creator',
      identifier: '10.13012/B2IDB-0012345_V1',
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

end
