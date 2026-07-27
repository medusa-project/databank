require 'rails_helper'

RSpec.describe IllinoisExpertsClient, type: :model do
  describe '.prefetch_person_xml_docs' do
    it 'normalizes, deduplicates, and fetches only internal emails' do
      john_doc = Nokogiri::XML('<person><organisationalUnit uuid="u1"/></person>')
      jane_doc = Nokogiri::XML('<person><organisationalUnit uuid="u2"/></person>')

      allow(described_class).to receive(:person_xml_doc).with('john@illinois.edu').and_return(john_doc)
      allow(described_class).to receive(:person_xml_doc).with('jane@uiuc.edu').and_return(jane_doc)

      result = described_class.prefetch_person_xml_docs([
        ' John@Illinois.edu ',
        'john@illinois.edu',
        'jane@uiuc.edu',
        'outside@example.org',
        '',
        nil
      ])

      expect(result.keys).to contain_exactly('john@illinois.edu', 'jane@uiuc.edu')
      expect(result['john@illinois.edu']).to eq(john_doc)
      expect(result['jane@uiuc.edu']).to eq(jane_doc)
      expect(described_class).to have_received(:person_xml_doc).with('john@illinois.edu').once
      expect(described_class).to have_received(:person_xml_doc).with('jane@uiuc.edu').once
    end

    it 'returns empty hash when there are no internal emails' do
      allow(described_class).to receive(:person_xml_doc)

      result = described_class.prefetch_person_xml_docs(['outside@example.org', 'another@org.net'])

      expect(result).to eq({})
      expect(described_class).not_to have_received(:person_xml_doc)
    end

    it 'preserves nil values for missing internal people' do
      allow(described_class).to receive(:person_xml_doc).with('missing@illinois.edu').and_return(nil)

      result = described_class.prefetch_person_xml_docs(['missing@illinois.edu'])

      expect(result).to eq({ 'missing@illinois.edu' => nil })
    end
  end

  describe '.person_xml_doc' do
    it 'returns nil without requesting API for non-internal emails' do
      allow(described_class).to receive(:get_response)

      result = described_class.person_xml_doc('outside@example.org')

      expect(result).to be_nil
      expect(described_class).not_to have_received(:get_response)
    end
  end
end
