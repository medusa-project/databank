require 'rails_helper'

RSpec.describe Dataset::Identifiable, type: :model do
  let(:dataset) do
    create(
      :dataset,
      key: 'TESTIDB-1234567',
      identifier: '10.13012/B2IDB-1234567_V1',
      title: 'Identifier Test Dataset',
      publication_state: Databank::PublicationState::RELEASED,
      hold_state: Databank::PublicationState::TempSuppress::NONE,
      release_date: Date.current
    )
  end

  describe '#default_identifier' do
    it 'uses the standard shoulder for non-test datasets' do
      dataset.is_test = false

      expect(dataset.default_identifier).to eq("#{IDB_CONFIG[:datacite][:shoulder]}#{dataset.key}_V1")
    end

    it 'uses the test shoulder for test datasets' do
      dataset.is_test = true

      expect(dataset.default_identifier).to eq("#{IDB_CONFIG[:datacite_test][:shoulder]}#{dataset.key}_V1")
    end
  end

  describe '#datacite_json_body' do
    it 'builds payload including event, doi, url and encoded xml' do
      allow(dataset).to receive(:to_datacite_xml).and_return('<resource/>')

      payload = dataset.datacite_json_body(Databank::DoiEvent::PUBLISH)

      expect(payload).to include('"event": "publish"')
      expect(payload).to include("\"doi\": \"#{dataset.identifier}\"")
      expect(payload).to include("\"url\": \"#{dataset.databank_url}\"")
      expect(payload).to include(Base64.strict_encode64('<resource/>'))
    end
  end

  describe '#to_datacite_xml' do
    it 'uses withdrawn xml for metadata-withdrawn hold state' do
      dataset.hold_state = Databank::PublicationState::PermSuppress::METADATA
      allow(dataset).to receive(:withdrawn_datacite_xml).and_return('withdrawn')

      expect(dataset.to_datacite_xml).to eq('withdrawn')
    end

    it 'uses embargoed xml for metadata embargo with future release date' do
      dataset.hold_state = Databank::PublicationState::TempSuppress::NONE
      dataset.embargo = Databank::PublicationState::Embargo::METADATA
      dataset.release_date = Date.current + 5
      allow(dataset).to receive(:embargoed_datacite_xml).and_return('embargoed')

      expect(dataset.to_datacite_xml).to eq('embargoed')
    end

    it 'uses complete xml for normal public metadata cases' do
      dataset.hold_state = Databank::PublicationState::TempSuppress::NONE
      dataset.embargo = Databank::PublicationState::Embargo::NONE
      allow(dataset).to receive(:complete_datacite_xml).and_return('complete')

      expect(dataset.to_datacite_xml).to eq('complete')
    end
  end

  describe '#embargoed_datacite_xml' do
    it 'raises if release date is missing for embargoed metadata' do
      dataset.release_date = nil

      expect { dataset.embargoed_datacite_xml }
        .to raise_error(RuntimeError, /missing release date/) 
    end

    it 'generates embargoed xml placeholders and available date' do
      dataset.release_date = Date.current + 7

      xml = dataset.embargoed_datacite_xml
      doc = Nokogiri::XML(xml)

      expect(doc.xpath('//*[local-name()="creatorName"]').text).to eq('[Embargoed]')
      expect(doc.xpath('//*[local-name()="title"]').text).to eq('[Embargoed]')
      expect(doc.xpath('//*[local-name()="date"][@dateType="Available"]').text).to eq(dataset.release_date.iso8601)
    end
  end

  describe '#withdrawn_datacite_xml' do
    it 'generates withdrawn metadata with redacted fields and withdrawn date' do
      dataset.release_date = Date.current - 1
      dataset.tombstone_date = Date.current

      xml = dataset.withdrawn_datacite_xml
      doc = Nokogiri::XML(xml)

      expect(doc.xpath('//*[local-name()="creatorName"]').text).to eq('[Redacted]')
      expect(doc.xpath('//*[local-name()="title"]').text).to eq('[Redacted]')
      expect(doc.xpath('//*[local-name()="date"][@dateType="Withdrawn"]').text).to eq(Date.current.iso8601)
    end
  end

  describe '#complete_datacite_xml' do
    it 'raises when contact creator is missing' do
      dataset.creators.destroy_all

      expect { dataset.complete_datacite_xml }
        .to raise_error(StandardError, /without contact/) 
    end

    it 'generates complete xml when a contact creator exists' do
      Creator.create!(
        dataset: dataset,
        given_name: 'Pat',
        family_name: 'Researcher',
        email: 'pat@illinois.edu',
        type_of: Databank::CreatorType::PERSON,
        row_order: 1,
        row_position: 1,
        is_contact: true
      )

      xml = dataset.complete_datacite_xml
      doc = Nokogiri::XML(xml)

      expect(doc.xpath('//*[local-name()="title"]').text).to include('Identifier Test Dataset')
      expect(doc.xpath('//*[local-name()="date"][@dateType="Available"]').text).to eq(dataset.release_date.iso8601)
      expect(doc.xpath('//*[local-name()="resourceType"]').text).to eq('Dataset')
    end
  end

  describe '#doi_infohash' do
    it 'returns empty hash when DataCite returns not found' do
      response = Net::HTTPNotFound.new('1.1', '404', 'Not Found')
      allow(dataset).to receive(:doi_info_from_datacite).and_return(response)

      expect(dataset.doi_infohash).to eq({})
    end

    it 'raises when DataCite returns unauthorized' do
      response = Net::HTTPUnauthorized.new('1.1', '401', 'Unauthorized')
      allow(dataset).to receive(:doi_info_from_datacite).and_return(response)

      expect { dataset.doi_infohash }.to raise_error(StandardError, /credentials could not be verified/)
    end

    it 'parses successful JSON response' do
      response = Net::HTTPOK.new('1.1', '200', 'OK')
      response.instance_variable_set(:@read, true)
      response.instance_variable_set(:@body, '{"data":{"attributes":{"state":"findable"}}}')
      allow(dataset).to receive(:doi_info_from_datacite).and_return(response)

      info = dataset.doi_infohash

      expect(info[:data][:attributes][:state]).to eq('findable')
    end
  end

  describe '#publish_doi' do
    before do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      allow(dataset).to receive(:sleep)
    end

    it 'returns error when identifier is missing' do
      dataset.identifier = nil

      expect(dataset.publish_doi[:status]).to eq('error')
    end

    it 'returns error when metadata is not public' do
      allow(dataset).to receive(:identifier_present?).and_return(true)
      allow(dataset).to receive(:metadata_public?).and_return(false)

      result = dataset.publish_doi

      expect(result[:status]).to eq('error')
      expect(result[:error_text]).to include('metadata can not be public')
    end

    it 'delegates to update_doi when state is already findable' do
      allow(dataset).to receive(:identifier_present?).and_return(true)
      allow(dataset).to receive(:metadata_public?).and_return(true)
      allow(dataset).to receive(:doi_state).and_return(Databank::DoiState::FINDABLE)
      allow(dataset).to receive(:update_doi).and_return(status: 'ok')

      expect(dataset.publish_doi).to eq(status: 'ok')
      expect(dataset).to have_received(:update_doi)
    end

    it 'creates draft then publishes to findable from unregistered state' do
      allow(dataset).to receive(:identifier_present?).and_return(true)
      allow(dataset).to receive(:metadata_public?).and_return(true)
      allow(dataset).to receive(:doi_state)
        .and_return(Databank::DoiState::UNREGISTERED, Databank::DoiState::DRAFT, Databank::DoiState::FINDABLE)
      allow(dataset).to receive(:create_draft_doi).and_return(status: 'ok')
      allow(dataset).to receive(:datacite_json_body).and_return('{"data":{}}')
      allow(Dataset).to receive(:put_to_datacite)

      expect(dataset.publish_doi).to eq(status: 'ok')
      expect(dataset).to have_received(:create_draft_doi)
      expect(Dataset).to have_received(:put_to_datacite).with(dataset.identifier, '{"data":{}}')
    end

    it 'returns error for invalid state transitions' do
      allow(dataset).to receive(:identifier_present?).and_return(true)
      allow(dataset).to receive(:metadata_public?).and_return(true)
      allow(dataset).to receive(:doi_state).and_return('bogus-state')

      result = dataset.publish_doi

      expect(result[:status]).to eq('error')
      expect(result[:error_text]).to include('invalid state for publish_doi')
    end
  end

  describe '#register_doi' do
    before do
      allow(dataset).to receive(:sleep)
    end

    it 'returns ok when state is registered and dataset update succeeds' do
      allow(dataset).to receive(:identifier_present?).and_return(true)
      allow(dataset).to receive(:doi_state).and_return(Databank::DoiState::REGISTERED)
      allow(dataset).to receive(:update).and_return(true)

      expect(dataset.register_doi).to eq(status: 'ok')
    end

    it 'returns error when state is registered and dataset update fails' do
      allow(dataset).to receive(:identifier_present?).and_return(true)
      allow(dataset).to receive(:doi_state).and_return(Databank::DoiState::REGISTERED)
      allow(dataset).to receive(:update).and_return(false)

      result = dataset.register_doi
      expect(result[:status]).to eq('error')
    end

    it 'returns invalid-state string when state after setup is not draft' do
      allow(dataset).to receive(:identifier_present?).and_return(true)
      allow(dataset).to receive(:doi_state).and_return(Databank::DoiState::FINDABLE)

      result = dataset.register_doi

      expect(result).to include('invalid DataCite state')
    end
  end

  describe '#hide_doi' do
    before do
      allow(dataset).to receive(:sleep)
    end

    it 'returns ok for unregistered state' do
      allow(dataset).to receive(:identifier_present?).and_return(true)
      allow(dataset).to receive(:doi_state).and_return(Databank::DoiState::UNREGISTERED)

      expect(dataset.hide_doi).to eq(status: 'ok')
    end

    it 'delegates draft state to delete_doi' do
      allow(dataset).to receive(:identifier_present?).and_return(true)
      allow(dataset).to receive(:doi_state).and_return(Databank::DoiState::DRAFT)
      allow(dataset).to receive(:delete_doi).and_return(status: 'ok')

      expect(dataset.hide_doi).to eq(status: 'ok')
      expect(dataset).to have_received(:delete_doi)
    end

    it 'hides findable doi and succeeds when resulting state becomes registered' do
      allow(dataset).to receive(:identifier_present?).and_return(true)
      allow(dataset).to receive(:doi_state).and_return(Databank::DoiState::FINDABLE, Databank::DoiState::REGISTERED)
      allow(dataset).to receive(:datacite_json_body).and_return('{"data":{}}')
      allow(Dataset).to receive(:put_to_datacite)

      expect(dataset.hide_doi).to eq(status: 'ok')
      expect(Dataset).to have_received(:put_to_datacite).with(dataset.identifier, '{"data":{}}')
    end
  end

  describe '#update_doi' do
    it 'returns error when identifier is missing' do
      dataset.identifier = nil

      expect(dataset.update_doi[:status]).to eq('error')
    end

    it 'forces released publication_state for findable DOI when dataset is not released' do
      dataset.publication_state = Databank::PublicationState::DRAFT
      allow(dataset).to receive(:doi_state).and_return(Databank::DoiState::FINDABLE)
      allow(dataset).to receive(:update).with(publication_state: Databank::PublicationState::RELEASED).and_return(true)

      expect(dataset.update_doi).to eq(status: 'ok')
    end

    it 'returns error when DataCite put response is nil' do
      allow(dataset).to receive(:doi_state).and_return(Databank::DoiState::REGISTERED)
      allow(dataset).to receive(:datacite_json_body).with(nil).and_return('{"data":{}}')
      allow(Dataset).to receive(:put_to_datacite).and_return(nil)

      result = dataset.update_doi
      expect(result[:status]).to eq('error')
    end

    it 'returns ok when DataCite returns code 200' do
      response = instance_double(Net::HTTPResponse, code: '200')
      allow(dataset).to receive(:doi_state).and_return(Databank::DoiState::REGISTERED)
      allow(dataset).to receive(:datacite_json_body).with(nil).and_return('{"data":{}}')
      allow(Dataset).to receive(:put_to_datacite).and_return(response)

      expect(dataset.update_doi).to eq(status: 'ok')
    end
  end

  describe '#delete_doi' do
    it 'returns ok when state is unregistered' do
      allow(dataset).to receive(:identifier_present?).and_return(true)
      allow(dataset).to receive(:doi_state).and_return(Databank::DoiState::UNREGISTERED)

      expect(dataset.delete_doi).to eq(status: 'ok')
    end

    it 'returns error when state is not draft for deletion' do
      allow(dataset).to receive(:identifier_present?).and_return(true)
      allow(dataset).to receive(:doi_state).and_return(Databank::DoiState::REGISTERED)

      result = dataset.delete_doi
      expect(result[:status]).to eq('error')
      expect(result[:error_text]).to include('can only remove DataCite DOIs in draft state')
    end
  end
end
