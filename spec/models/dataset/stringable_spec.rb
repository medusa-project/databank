require 'rails_helper'
require 'ostruct'

RSpec.describe Dataset::Stringable, type: :model do
  describe '#structured_data' do
    it 'returns an empty string when dataset is not released' do
      dataset = build(:dataset, publication_state: Databank::PublicationState::DRAFT)

      expect(dataset.structured_data).to eq('')
    end

    it 'builds schema content with creators, keywords, funders, and license link' do
      dataset = build(
        :dataset,
        publication_state: Databank::PublicationState::RELEASED,
        title: 'Climate "Signals"',
        description: "  line one\nline two  ",
        keywords: 'alpha; beta',
        dataset_version: '2',
        key: 'TESTKEY',
        license: 'CCBY4'
      )

      stub_const('LICENSE_INFO_ARR', [OpenStruct.new(code: 'CCBY4', external_info_url: 'https://license.example/ccby4')])
      allow(dataset).to receive(:persistent_url).and_return('https://doi.org/10.1000/test')
      allow(dataset).to receive(:plain_text_citation).and_return('Doe, Jane: "quoted" text')
      allow(dataset).to receive(:creators).and_return([
        double(given_name: 'Jane', family_name: 'Doe', identifier: '0000-0000-0000-0001'),
        double(given_name: 'Alex', family_name: 'Smith', identifier: nil)
      ])
      allow(dataset).to receive(:funders).and_return([
        double(name: 'National Science Foundation', identifier: '10.1234/funder')
      ])

      result = dataset.structured_data

      expect(result).to include('"@type": "Dataset"')
      expect(result).to include('"keywords": "alpha, beta"')
      expect(result).to include('http://orcid.org/0000-0000-0000-0001')
      expect(result).to include('"funder": [')
      expect(result).to include('https://license.example/ccby4')
      expect(result).to include('https://doi.org/10.1000/test')
    end

    it 'uses license.txt fallback text when no external license link is found' do
      dataset = build(:dataset, publication_state: Databank::PublicationState::RELEASED, license: 'license.txt')

      stub_const('LICENSE_INFO_ARR', [OpenStruct.new(code: 'CCBY4', external_info_url: 'https://license.example/ccby4')])
      allow(dataset).to receive(:persistent_url).and_return('https://doi.org/10.1000/test')
      allow(dataset).to receive(:plain_text_citation).and_return('citation')
      allow(dataset).to receive(:creators).and_return([])
      allow(dataset).to receive(:funders).and_return([])

      result = dataset.structured_data

      expect(result).to include('"license":"See license.txt"')
    end
  end

  describe '#creator_list' do
    it 'returns placeholder when no creators exist' do
      dataset = build(:dataset)
      allow(Creator).to receive(:where).with(dataset_id: dataset.id).and_return([])

      expect(dataset.creator_list).to eq('[Creator List]')
    end

    it 'returns single creator list name for one creator' do
      dataset = build(:dataset)
      creator = double(institution_name: '', family_name: 'Doe', list_name: 'Doe, Jane')
      allow(Creator).to receive(:where).with(dataset_id: dataset.id).and_return([creator])

      expect(dataset.creator_list).to eq('Doe, Jane')
    end

    it 'joins multiple creators using semicolon separators' do
      dataset = build(:dataset)
      creator1 = double(list_name: 'Doe, Jane')
      creator2 = double(list_name: 'Smith, Alex')
      allow(Creator).to receive(:where).with(dataset_id: dataset.id).and_return([creator1, creator2])
      allow(dataset).to receive(:creators).and_return([creator1, creator2])

      expect(dataset.creator_list).to eq('Doe, Jane; Smith, Alex')
    end
  end

  describe '#bibtex_creator_list' do
    it 'returns placeholder when creators are missing' do
      dataset = build(:dataset)
      allow(dataset).to receive(:creators).and_return([])

      expect(dataset.bibtex_creator_list).to eq('[Creator List]')
    end

    it 'joins multiple creators with and for bibtex output' do
      dataset = build(:dataset)
      creator1 = double(list_name: 'Doe, Jane')
      creator2 = double(list_name: 'Smith, Alex')
      allow(dataset).to receive(:creators).and_return([creator1, creator2])

      expect(dataset.bibtex_creator_list).to eq('Doe, Jane and Smith, Alex')
    end
  end

  describe '#contributor_list' do
    it 'returns nil when there are no contributors' do
      dataset = build(:dataset)
      allow(dataset).to receive(:contributors).and_return([])

      expect(dataset.contributor_list).to be_nil
    end

    it 'joins multiple contributors with semicolon separators' do
      dataset = build(:dataset)
      contributor1 = double(display_name: 'Jane Doe')
      contributor2 = double(display_name: 'Alex Smith')
      allow(dataset).to receive(:contributors).and_return([contributor1, contributor2])

      expect(dataset.contributor_list).to eq('Jane Doe; Alex Smith')
    end
  end

  describe '#record_text' do
    it 'returns invalid method text when identifier is blank' do
      dataset = build(:dataset, identifier: '')

      expect(dataset.record_text).to eq('Method not valid for draft dataset.')
    end

    it 'builds citation text with license, funder, related material, and files' do
      dataset = build(
        :dataset,
        identifier: '10.13012/B2IDB-7654321_V1',
        title: 'Dataset Title',
        publisher: 'University of Illinois Urbana-Champaign',
        description: 'dataset description',
        keywords: 'alpha;beta',
        license: 'CCBY4',
        corresponding_creator_name: 'Jane Doe'
      )

      datafile = double(bytestream_name: 'data.csv', bytestream_size: 1024)
      material = double(
        uri: nil,
        relationship_arr: [],
        citation: 'Companion article',
        link: 'https://example.org/article',
        material_type: 'Article'
      )
      funder = double(name: 'NSF', grant: 'ABC-123')

      allow(dataset).to receive(:creator_list).and_return('Doe, Jane')
      allow(dataset).to receive(:creators).and_return([double])
      allow(dataset).to receive(:publication_year).and_return('2026')
      allow(dataset).to receive(:plain_text_citation).and_return('Doe, Jane (2026): Dataset Title. Publisher. DOI')
      allow(dataset).to receive(:funders).and_return([funder])
      allow(dataset).to receive(:related_materials).and_return([material])
      allow(dataset).to receive(:datafiles).and_return([datafile])
      allow(dataset).to receive(:complete_datafiles).and_return([datafile])
      allow(ApplicationController.helpers).to receive(:number_to_human_size).with(1024).and_return('1 KB')

      result = dataset.record_text

      expect(result).to include('[ DOI: ] 10.13012/B2IDB-7654321_V1')
      expect(result).to include('[ License: ] CC BY - http://creativecommons.org/licenses/by/4.0/')
      expect(result).to include('[ Funder: ] NSF- [ Grant: ] ABC-123')
      expect(result).to include('[ Related Article: ] Companion article, https://example.org/article')
      expect(result).to include('. data.csv, 1 KB')
    end
  end
end
