require 'rails_helper'

RSpec.describe Dataset::Exportable, type: :model do
  describe '.to_illinois_experts' do
    let(:where_scope) { instance_double(ActiveRecord::Relation) }

    it 'returns nil when no datasets are eligible for export' do
      ineligible_dataset = instance_double(Dataset, metadata_public?: false)
      allow(Dataset).to receive(:where).with(is_test: false).and_return(where_scope)
      allow(where_scope).to receive(:where).with(org_creators: false).and_return([ineligible_dataset])

      expect(Dataset.to_illinois_experts).to be_nil
    end

    it 'exports only eligible datasets and includes expected XML structure' do
      eligible = instance_double(
        Dataset,
        key: 'ELIGIBLE-1',
        title: 'Published Dataset',
        description: 'Export description',
        identifier: '10.13012/B2IDB-1234567_V1',
        metadata_public?: true,
        keywords: 'earth science; machine learning',
        release_date: Date.new(2024, 2, 3)
      )

      ineligible_dataset = instance_double(Dataset, metadata_public?: false)

      internal_creator = instance_double(
        Creator,
        email: 'internal@illinois.edu',
        is_contact: true,
        at_illinois?: true,
        given_name: 'Internal',
        family_name: 'Creator'
      )
      illinois_external_creator = instance_double(
        Creator,
        email: 'external@illinois.edu',
        is_contact: false,
        at_illinois?: true,
        given_name: 'Illinois',
        family_name: 'External'
      )
      external_creator = instance_double(
        Creator,
        email: 'outside@example.org',
        is_contact: false,
        at_illinois?: false,
        given_name: 'Outside',
        family_name: 'Creator'
      )
      blank_email_creator = instance_double(
        Creator,
        email: '   ',
        is_contact: false,
        at_illinois?: false,
        given_name: 'Blank',
        family_name: 'Email'
      )

      allow(eligible).to receive(:individual_creators).and_return(
        [internal_creator, illinois_external_creator, external_creator, blank_email_creator]
      )

      allow(Dataset).to receive(:where).with(is_test: false).and_return(where_scope)
      allow(where_scope).to receive(:where).with(org_creators: false).and_return([eligible, ineligible_dataset])

      internal_person_doc = Nokogiri::XML(
        '<person><organisationalUnit uuid="unit-123"/><period><startDate>2021-04-05</startDate></period></person>'
      )

      allow(IllinoisExpertsClient).to receive(:person_xml_doc).and_return(nil)
      allow(IllinoisExpertsClient).to receive(:person_xml_doc)
        .with(internal_creator.email)
        .and_return(internal_person_doc)

      xml = Dataset.to_illinois_experts

      expect(xml).to be_present

      doc = Nokogiri::XML(xml)
      namespaces = { 'v1' => 'v1.dataset.pure.atira.dk', 'v3' => 'v3.commons.pure.atira.dk' }

      dataset_nodes = doc.xpath('//v1:dataset', namespaces)
      expect(dataset_nodes.count).to eq(1)

      dataset_node = dataset_nodes.first
      expect(dataset_node['id']).to eq('doi:10.13012/B2IDB-1234567_V1')
      expect(dataset_node.at_xpath('v1:title', namespaces).text).to eq('Published Dataset')
      expect(dataset_node.at_xpath('v1:description', namespaces).text).to eq('Export description')
      expect(dataset_node.at_xpath('v1:DOI', namespaces).text).to eq('10.13012/B2IDB-1234567_V1')

      expect(dataset_node.at_xpath('v1:managingOrganisation', namespaces)['lookupId'])
        .to eq(IDB_CONFIG[:illinois_experts][:org_id])
      expect(dataset_node.at_xpath('v1:publisher', namespaces)['lookupId'])
        .to eq(IDB_CONFIG[:illinois_experts][:publisher_id])

      expect(dataset_node.at_xpath('v1:availableDate/v3:year', namespaces).text).to eq('2024')
      expect(dataset_node.at_xpath('v1:availableDate/v3:month', namespaces).text).to eq('02')
      expect(dataset_node.at_xpath('v1:availableDate/v3:day', namespaces).text).to eq('03')

      keyword_nodes = dataset_node.xpath('v1:keywords/v1:keyword', namespaces)
      expect(keyword_nodes.map(&:text)).to contain_exactly('earth science', 'machine learning')

      person_nodes = dataset_node.xpath('v1:persons/v1:person', namespaces)
      expect(person_nodes.count).to eq(3)

      internal_person = dataset_node.at_xpath("v1:persons/v1:person[@id='#{internal_creator.email}']", namespaces)
      expect(internal_person).to be_present
      expect(internal_person['contactPerson']).to eq('true')
      expect(internal_person.at_xpath('v1:person', namespaces)['lookupId']).to eq(internal_creator.email)
      expect(internal_person.at_xpath('v1:organisations/v1:organisation', namespaces)['lookupId']).to eq('unit-123')
      expect(internal_person.at_xpath('v1:associationStartDate', namespaces).text).to eq('2021-04-05')

      illinois_external = dataset_node.at_xpath(
        "v1:persons/v1:person[@id='#{illinois_external_creator.email}']",
        namespaces
      )
      expect(illinois_external).to be_present
      expect(illinois_external.at_xpath('v1:person', namespaces)['origin']).to eq('external')
      expect(illinois_external.at_xpath('v1:organisations/v1:organisation', namespaces)['lookupId'])
        .to eq(IDB_CONFIG[:illinois_experts][:illinois_external_org_id])

      external = dataset_node.at_xpath("v1:persons/v1:person[@id='#{external_creator.email}']", namespaces)
      expect(external).to be_present
      expect(external.at_xpath('v1:person', namespaces)['origin']).to eq('external')
      expect(external.at_xpath('v1:organisations/v1:organisation/v1:name', namespaces).text).to eq('unknown')
    end
  end
end
