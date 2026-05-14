require 'rails_helper'

RSpec.describe Creator, type: :model do
  let(:dataset) { create(:dataset) }

  # ─── validations ──────────────────────────────────────────────────────────────

  describe 'validations' do
    it 'is valid with person name attributes' do
      expect(build(:creator, dataset: dataset)).to be_valid
    end

    it 'is valid with institution_name' do
      expect(build(:creator, :institution, dataset: dataset)).to be_valid
    end

    it 'is invalid without any name' do
      creator = build(:creator, given_name: nil, family_name: nil, institution_name: nil,
                                email: 'test@example.org', dataset: dataset)
      expect(creator).not_to be_valid
      expect(creator.errors[:base]).to include(/institution name or both/)
    end
  end

  # ─── display helpers ──────────────────────────────────────────────────────────

  describe '#display_name' do
    it 'returns institution_name for institution creators' do
      creator = build(:creator, :institution, institution_name: 'UIUC Library', dataset: dataset)
      expect(creator.display_name).to eq('UIUC Library')
    end

    it 'concatenates given and family name for person creators' do
      creator = build(:creator, given_name: 'Jane', family_name: 'Doe', dataset: dataset)
      expect(creator.display_name).to eq('Jane Doe')
    end
  end

  describe '#list_name' do
    it 'returns institution_name for institution creators' do
      creator = build(:creator, :institution, institution_name: 'UIUC Library', dataset: dataset)
      expect(creator.list_name).to eq('UIUC Library')
    end

    it 'returns "family, given" for person creators' do
      creator = build(:creator, given_name: 'Jane', family_name: 'Doe', dataset: dataset)
      expect(creator.list_name).to eq('Doe, Jane')
    end
  end

  describe '#display_info' do
    it 'combines display_name, email, and identifier' do
      creator = build(:creator, given_name: 'Jane', family_name: 'Doe',
                                email: 'jane@example.org', identifier: '0000-0001', dataset: dataset)
      expect(creator.display_info).to eq('Jane Doe, jane@example.org, 0000-0001')
    end
  end

  # ─── as_json ──────────────────────────────────────────────────────────────────

  describe '#as_json' do
    it 'returns institution fields for institutional creators' do
      creator = build(:creator, :institution, dataset: dataset)
      json = creator.as_json
      expect(json.keys).to include('institution_name')
      expect(json.keys).not_to include('family_name')
    end

    it 'returns person fields for person creators' do
      creator = build(:creator, dataset: dataset)
      json = creator.as_json
      expect(json.keys).to include('family_name')
      expect(json.keys).not_to include('institution_name')
    end
  end

  # ─── at_illinois? ─────────────────────────────────────────────────────────────

  describe '#at_illinois?' do
    it 'returns false for institution creators' do
      creator = build(:creator, :institution, dataset: dataset)
      expect(creator.at_illinois?).to be false
    end

    it 'returns false for person creator with blank email' do
      creator = build(:creator, type_of: Databank::CreatorType::PERSON, email: '', dataset: dataset)
      expect(creator.at_illinois?).to be false
    end

    it 'returns true for a person with an illinois.edu email' do
      creator = build(:creator, type_of: Databank::CreatorType::PERSON, email: 'person@illinois.edu', dataset: dataset)
      expect(creator.at_illinois?).to be true
    end

    it 'returns false for a person with a non-illinois email' do
      creator = build(:creator, type_of: Databank::CreatorType::PERSON, email: 'person@example.org', dataset: dataset)
      expect(creator.at_illinois?).to be false
    end
  end

  # ─── .orcid_query_string ──────────────────────────────────────────────────────

  describe '.orcid_query_string' do
    it 'raises ArgumentError when both arguments are nil' do
      expect { Creator.orcid_query_string }.to raise_error(ArgumentError)
    end

    it 'searches only by given name when family_name is omitted' do
      expect(Creator.orcid_query_string(given_names: 'Jane')).to include('given-names:Jane')
    end

    it 'searches only by family name when given_names is omitted' do
      expect(Creator.orcid_query_string(family_name: 'Doe')).to include('family-name:Doe')
    end

    it 'combines both names in the query string' do
      result = Creator.orcid_query_string(family_name: 'Doe', given_names: 'Jane')
      expect(result).to include('family-name:Doe')
      expect(result).to include('given-names:Jane')
    end
  end

  # ─── .orcid_identifier ────────────────────────────────────────────────────────

  describe '.orcid_identifier' do
    let(:orcid_search_xml) do
      <<~XML
        <search:search xmlns:search="http://www.orcid.org/ns/search"
                       xmlns:common="http://www.orcid.org/ns/common"
                       num-found="1">
          <common:path>0000-0001-2345-6789</common:path>
        </search:search>
      XML
    end

    it 'returns num-found and orcid result list from a stubbed HTTP response' do
      allow_any_instance_of(OpenURI::OpenRead).to receive(:read).and_return(orcid_search_xml)

      result = Creator.orcid_identifier(family_name: 'Doe', given_names: 'Jane')

      expect(result['num-found']).to eq(1)
      expect(result['result'].first['orcid-identifier']).to eq('0000-0001-2345-6789')
    end
  end

  # ─── .orcid_person ────────────────────────────────────────────────────────────

  describe '.orcid_person' do
    context 'with affiliation present' do
      let(:person_xml) do
        <<~XML
          <record:record xmlns:record="http://www.orcid.org/ns/record"
                         xmlns:personal-details="http://www.orcid.org/ns/personal-details"
                         xmlns:common="http://www.orcid.org/ns/common">
            <personal-details:name>
              <personal-details:family-name>Doe</personal-details:family-name>
              <personal-details:given-names>Jane</personal-details:given-names>
            </personal-details:name>
            <common:organization>
              <common:name>UIUC</common:name>
            </common:organization>
          </record:record>
        XML
      end

      it 'returns family name, given names, and affiliation' do
        allow_any_instance_of(OpenURI::OpenRead).to receive(:read).and_return(person_xml)

        result = Creator.orcid_person(orcid: '0000-0001-2345-6789')

        expect(result[:family_name]).to eq('Doe')
        expect(result[:given_names]).to eq('Jane')
        expect(result[:affiliation]).to eq('UIUC')
      end
    end

    context 'without affiliation' do
      let(:person_xml_no_affil) do
        <<~XML
          <record:record xmlns:record="http://www.orcid.org/ns/record"
                         xmlns:personal-details="http://www.orcid.org/ns/personal-details"
                         xmlns:common="http://www.orcid.org/ns/common">
            <personal-details:name>
              <personal-details:family-name>Smith</personal-details:family-name>
              <personal-details:given-names>Alex</personal-details:given-names>
            </personal-details:name>
          </record:record>
        XML
      end

      it 'returns "not provided" when affiliation node is absent' do
        allow_any_instance_of(OpenURI::OpenRead).to receive(:read).and_return(person_xml_no_affil)

        result = Creator.orcid_person(orcid: '0000-0001-9999-0000')

        expect(result[:affiliation]).to eq('not provided')
      end
    end
  end

  # ─── callbacks: remove_editor ─────────────────────────────────────────────────

  describe 'before_destroy :remove_editor' do
    it 'calls remove_from_editors and reindexes when the creator is destroyed' do
      creator = create(:creator, dataset: dataset)

      allow(UserAbility).to receive(:remove_from_editors)
      allow(Sunspot).to receive(:index!)

      creator.destroy

      expect(UserAbility).to have_received(:remove_from_editors)
        .with(dataset: dataset, email: creator.email)
      expect(Sunspot).to have_received(:index!).with([dataset])
    end
  end
end
