require 'rails_helper'

RSpec.describe Dataset::Complete, type: :model do
  describe '#valid_change2published' do
    def publish_params(identifier:, identifer:, embargo:, title:, creators_attributes:, license:, release_date: '')
      ActionController::Parameters.new(
        dataset: ActionController::Parameters.new(
          identifier: identifier,
          identifer: identifer,
          embargo: embargo,
          title: title,
          creators_attributes: creators_attributes,
          license: license,
          release_date: release_date
        )
      )
    end

    it 'returns suppression message when metadata is permanently suppressed' do
      dataset = build(:dataset, publication_state: Databank::PublicationState::PermSuppress::METADATA)

      result = dataset.valid_change2published(new_params: ActionController::Parameters.new(dataset: {}))

      expect(result).to eq('Permanently suppressed dataset cannot be published.')
    end

    it 'returns invalid params when identifier/identifer keys do not satisfy guard' do
      dataset = build(:dataset)
      params = ActionController::Parameters.new(dataset: { title: 'A title' })

      result = dataset.valid_change2published(new_params: params)

      expect(result).to include('invalid params:')
    end

    it 'returns ok when required fields are present and no helper errors exist' do
      dataset = build(:dataset, identifier: '10.13012/B2IDB-1234567_V1')
      creators_attributes = ActionController::Parameters.new(
        '0' => ActionController::Parameters.new(is_contact: '1')
      )
      params = publish_params(
        identifier: '10.13012/B2IDB-1234567_V1',
        identifer: '10.13012/B2IDB-1234567_V1',
        embargo: Databank::PublicationState::Embargo::NONE,
        title: 'Dataset Title',
        creators_attributes: creators_attributes,
        license: 'CC01'
      )

      allow(dataset).to receive(:complete_datafiles).and_return([double])
      allow(dataset).to receive(:datafiles).and_return([])
      allow(Dataset).to receive(:update_embargo_errors).and_return(nil)

      expect(dataset.valid_change2published(new_params: params)).to eq('ok')
    end

    it 'returns aggregated validation errors when key requirements are missing' do
      dataset = build(:dataset, identifier: '10.13012/B2IDB-8888888_V1')
      creators_attributes = ActionController::Parameters.new
      params = publish_params(
        identifier: '10.13012/B2IDB-9999999_V1',
        identifer: '10.13012/B2IDB-9999999_V1',
        embargo: Databank::PublicationState::Embargo::FILE,
        title: '',
        creators_attributes: creators_attributes,
        license: ''
      )

      allow(dataset).to receive(:complete_datafiles).and_return([])
      allow(dataset).to receive(:datafiles).and_return(Array.new(501) { double })
      allow(Dataset).to receive(:where).with(identifier: '10.13012/B2IDB-9999999_V1').and_return(double(count: 1))
      allow(Dataset).to receive(:update_embargo_errors).and_return(['embargo mismatch'])

      result = dataset.valid_change2published(new_params: params)

      expect(result).to include('Required elements for a complete dataset missing:')
      expect(result).to include('release date')
      expect(result).to include('title')
      expect(result).to include('at least one creator')
      expect(result).to include('license')
      expect(result).to include('at least one file')
      expect(result).to include('a unique DOI')
      expect(result).to include('embargo mismatch')
      expect(result).to include('500 or fewer datafiles')
    end
  end

  describe '.completion_check' do
    it 'returns na when metadata is permanently suppressed' do
      dataset = build(:dataset, publication_state: Databank::PublicationState::PermSuppress::METADATA)

      expect(Dataset.completion_check(dataset)).to eq('na')
    end

    it 'returns ok when all checks pass' do
      dataset = build(:dataset, title: 'Dataset Title', license: 'CC01')
      allow(dataset).to receive(:creators).and_return([double])
      allow(dataset).to receive(:complete_datafiles).and_return([double])
      allow(dataset).to receive(:incomplete_datafiles).and_return([])
      allow(dataset).to receive(:contact).and_return(double)
      allow(dataset).to receive(:is_import?).and_return(false)
      allow(dataset).to receive(:datafiles).and_return([])
      allow(Dataset).to receive(:license_error).and_return(nil)
      allow(Dataset).to receive(:creator_email_errors).and_return([])
      allow(Dataset).to receive(:duplicate_doi_error).and_return(nil)
      allow(Dataset).to receive(:duplicate_datafile_error).and_return(nil)
      allow(Dataset).to receive(:embargo_errors).and_return(nil)
      allow(Dataset).to receive(:import_date_errors).and_return(nil)
      allow(Dataset).to receive(:related_material_errors).and_return([])

      expect(Dataset.completion_check(dataset)).to eq('ok')
    end

    it 'returns aggregated errors when multiple checks fail' do
      dataset = build(:dataset, title: '', license: '')
      allow(dataset).to receive(:creators).and_return([])
      allow(dataset).to receive(:complete_datafiles).and_return([])
      allow(dataset).to receive(:incomplete_datafiles).and_return([double])
      allow(dataset).to receive(:contact).and_return(nil)
      allow(dataset).to receive(:is_import?).and_return(true)
      allow(dataset).to receive(:identifier).and_return(nil)
      allow(dataset).to receive(:datafiles).and_return(Array.new(501) { double })
      allow(Dataset).to receive(:license_error).and_return(['license helper error'])
      allow(Dataset).to receive(:creator_email_errors).and_return(['creator email helper error'])
      allow(Dataset).to receive(:duplicate_doi_error).and_return(['doi helper error'])
      allow(Dataset).to receive(:duplicate_datafile_error).and_return(['duplicate file helper error'])
      allow(Dataset).to receive(:embargo_errors).and_return(['embargo helper error'])
      allow(Dataset).to receive(:import_date_errors).and_return(['import date helper error'])
      allow(Dataset).to receive(:related_material_errors).and_return(['related material helper error'])

      result = Dataset.completion_check(dataset)

      expect(result).to include('title')
      expect(result).to include('at least one creator')
      expect(result).to include('license')
      expect(result).to include('at least one file')
      expect(result).to include('remove incomplete uploads')
      expect(result).to include('select primary contact from author list')
      expect(result).to include('identifier to import')
      expect(result).to include('license helper error')
      expect(result).to include('creator email helper error')
      expect(result).to include('doi helper error')
      expect(result).to include('duplicate file helper error')
      expect(result).to include('embargo helper error')
      expect(result).to include('import date helper error')
      expect(result).to include('related material helper error')
      expect(result).to include('500 or fewer datafiles')
    end
  end

  describe 'helper methods' do
    it 'creator_email_errors returns error when any creator email is blank' do
      dataset = build(:dataset)
      allow(dataset).to receive(:creators).and_return([double(email: 'ok@example.edu'), double(email: '')])

      expect(Dataset.creator_email_errors(dataset)).to eq(['an email address for all creators'])
    end

    it 'license_error requires a license.txt file for custom license selection' do
      dataset = build(:dataset, license: 'license.txt')
      allow(dataset).to receive(:datafiles).and_return([double(bytestream_name: 'README.txt')])

      expect(Dataset.license_error(dataset)).to eq(['a license file named license.txt or a different license selection'])
    end

    it 'duplicate_datafile_error reports the first duplicate filename' do
      dataset = build(:dataset)
      allow(dataset).to receive(:datafiles).and_return([
        double(bytestream_name: 'a.csv'),
        double(bytestream_name: 'b.csv'),
        double(bytestream_name: 'a.csv')
      ])

      expect(Dataset.duplicate_datafile_error(dataset)).to eq(['no duplicate filenames (a.csv)'])
    end

    it 'embargo_errors detects future-date mismatch for non-embargo selection' do
      dataset = build(
        :dataset,
        embargo: Databank::PublicationState::Embargo::NONE,
        release_date: Date.current + 3.days
      )

      expect(Dataset.embargo_errors(dataset)).to eq(['a delayed publication (embargo) selection for a future release date'])
    end

    it 'update_embargo_errors detects embargo selection with non-future release date' do
      params = ActionController::Parameters.new(
        dataset: ActionController::Parameters.new(
          embargo: Databank::PublicationState::Embargo::FILE,
          release_date: Date.current.iso8601
        )
      )

      expect(Dataset.update_embargo_errors(params: params))
        .to eq(['a future release date for delayed publication (embargo) selection'])
    end

    it 'related_material_errors requires uri_type when uri is present' do
      dataset = build(:dataset)
      material = double(uri_type: '', uri: 'https://example.org')
      allow(dataset).to receive(:related_materials).and_return([material])

      expect(Dataset.related_material_errors(dataset)).to eq(['a uri_type for uri for each related material'])
    end

    it 'detects primary contact and key presence helper logic' do
      creator_params = {
        '0' => {given_name: 'Jane'},
        '1' => {is_contact: '1'}
      }
      params = {dataset: {title: 'Dataset Title'}}

      expect(Dataset.has_primary_contact?(creator_params: creator_params)).to be true
      expect(Dataset.key_not_empty?(params: params, key: :title)).to be true
      expect(Dataset.key_not_empty?(params: params, key: :license)).to be false
    end
  end
end
