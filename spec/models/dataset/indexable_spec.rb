require 'rails_helper'
require 'ostruct'

RSpec.describe Dataset::Indexable, type: :model do
  describe 'class methods' do
    describe '.visibility_name_from_code' do
      it 'maps known visibility codes to display text' do
        expect(Dataset.visibility_name_from_code('released')).to eq('Metadata and Files Published')
        expect(Dataset.visibility_name_from_code('suppressed_v')).to eq('Version Candidate Draft Pending Approval')
      end

      it 'warns and falls back to unknown for unrecognized codes' do
        allow(Rails.logger).to receive(:warn)

        expect(Dataset.visibility_name_from_code('mystery-code')).to eq('Unknown')
        expect(Rails.logger).to have_received(:warn).with(/visibility state not found for code: mystery-code/)
      end
    end

    describe '.license_name_from_code' do
      it 'returns unselected and custom codes directly' do
        expect(Dataset.license_name_from_code('unselected')).to eq('unselected')
        expect(Dataset.license_name_from_code('custom')).to eq('custom')
      end

      it 'returns the matching license name when the code exists' do
        stub_const('LICENSE_INFO_ARR', [OpenStruct.new(code: 'CCBY4', name: 'Creative Commons Attribution 4.0')])

        expect(Dataset.license_name_from_code('CCBY4')).to eq('Creative Commons Attribution 4.0')
      end

      it 'returns the code when no matching license is found' do
        stub_const('LICENSE_INFO_ARR', [])

        expect(Dataset.license_name_from_code('MISSING')).to eq('MISSING')
      end
    end

    describe '.funder_name_from_code' do
      it 'returns Other for the special other code' do
        expect(Dataset.funder_name_from_code('other')).to eq('Other')
      end

      it 'returns the matching funder name when present' do
        stub_const('FUNDER_INFO_ARR', [OpenStruct.new(code: 'nsf', name: 'National Science Foundation')])

        expect(Dataset.funder_name_from_code('nsf')).to eq('National Science Foundation')
      end

      it 'returns funder not found when no funder matches' do
        stub_const('FUNDER_INFO_ARR', [])

        expect(Dataset.funder_name_from_code('missing')).to eq('funder not found')
      end
    end

    describe '.pubstate_name_from_code' do
      it 'returns draft for objects matching the Databank module case branch' do
        code = Object.new.extend(Databank)

        expect(Dataset.pubstate_name_from_code(code)).to eq('draft')
      end

      it 'returns not draft for other values' do
        expect(Dataset.pubstate_name_from_code('released')).to eq('not draft')
      end
    end

    describe '.citation_report' do
      let(:search) { double('search') }
      let(:dataset_with_release) do
        double(
          plain_text_citation: 'Citation One',
          funders: [double(name: 'NSF', grant: 'ABC-123')],
          total_downloads: 7,
          release_datetime: Time.zone.parse('2024-01-02 03:04:05')
        )
      end
      let(:dataset_without_release) do
        double(
          plain_text_citation: 'Citation Two',
          funders: [double(name: 'NIH', grant: '')],
          total_downloads: 2,
          release_datetime: nil
        )
      end

      it 'builds a report with user, query url, grants, and release-date fallbacks' do
        allow(search).to receive(:each_hit_with_result)
          .and_yield(nil, dataset_with_release)
          .and_yield(nil, dataset_without_release)

        report = Dataset.citation_report(search, 'https://example.test/search?q=alpha', double(username: 'curator'))

        expect(report).to include('Illinois Data Bank')
        expect(report).to include("generated #{Date.current.iso8601} by curator")
        expect(report).to include('Query URL: https://example.test/search?q=alpha')
        expect(report).to include('Citation One')
        expect(report).to include('Funder: NSF, Grant: ABC-123')
        expect(report).to include('Downloads: 7 (2024-01-02 to')
        expect(report).to include('Citation Two')
        expect(report).to include("Citation Two\nFunder: NIH\nDownloads: 2")
      end

      it 'omits the username suffix when current user has no username' do
        allow(search).to receive(:each_hit_with_result)

        report = Dataset.citation_report(search, 'https://example.test/search', nil)

        expect(report).to include("Datasets Report, generated #{Date.current.iso8601}")
        expect(report).not_to include(' by ')
      end
    end
  end

  describe '#visibility' do
    it 'returns unsaved draft for new records regardless of other state' do
      dataset = build(:dataset, publication_state: Databank::PublicationState::RELEASED)

      expect(dataset.visibility).to eq('Unsaved Draft')
    end

    it 'returns metadata suppressed when hold state suppresses metadata' do
      dataset = create(:dataset, hold_state: Databank::PublicationState::TempSuppress::METADATA)

      expect(dataset.visibility).to eq('Metadata and Files Temporarily Suppressed')
    end

    it 'returns embargoed file visibility when file hold and file embargo are combined' do
      dataset = create(
        :dataset,
        hold_state: Databank::PublicationState::TempSuppress::FILE,
        publication_state: Databank::PublicationState::Embargo::FILE
      )

      expect(dataset.visibility).to eq('Metadata Published, Files Publication Delayed (Embargoed)')
    end

    it 'returns the unknown message for unexpected publication states' do
      dataset = create(:dataset, publication_state: 'unexpected-state', hold_state: Databank::PublicationState::TempSuppress::NONE)

      expect(dataset.visibility).to eq('Unknown, please contact the Research Data Service')
    end
  end

  describe '#visibility_code' do
    it 'returns new for unsaved records' do
      dataset = build(:dataset, publication_state: Databank::PublicationState::RELEASED)

      expect(dataset.visibility_code).to eq('new')
    end

    it 'returns suppressed_v when hold state is version' do
      dataset = create(:dataset, hold_state: Databank::PublicationState::TempSuppress::VERSION)

      expect(dataset.visibility_code).to eq('suppressed_v')
    end

    it 'warns and returns unknown for unexpected persisted states' do
      dataset = create(:dataset, key: 'TESTIDB-INDEXABLE', publication_state: 'unexpected-state', hold_state: Databank::PublicationState::TempSuppress::NONE)
      allow(Rails.logger).to receive(:warn)

      expect(dataset.visibility_code).to eq('unknown')
      expect(Rails.logger).to have_received(:warn).with(/visibility code not found for: TESTIDB-INDEXABLE/)
    end
  end

  describe 'aggregation helpers' do
    let(:dataset) { create(:dataset, depositor_email: 'depositor@example.org', subject: '') }

    before do
      Funder.create!(dataset_id: dataset.id, name: 'NSF', code: 'nsf', grant: 'ABC-123')
      Funder.create!(dataset_id: dataset.id, name: 'NIH', code: 'nih', grant: 'XYZ-987')
      UserAbility.create!(resource_type: 'Dataset', ability: 'view_files', resource_id: dataset.id, user_provider: 'developer', user_uid: 'reviewer@example.org')
      UserAbility.create!(resource_type: 'Dataset', ability: 'view_files', resource_id: dataset.id, user_provider: 'developer', user_uid: 'reviewer@example.org')
      UserAbility.create!(resource_type: 'Dataset', ability: 'update', resource_id: dataset.id, user_provider: 'developer', user_uid: 'editor@example.org')
      UserAbility.create!(resource_type: 'Dataset', ability: 'update', resource_id: dataset.id, user_provider: 'developer', user_uid: 'reviewer@example.org')
      create(:datafile, dataset: dataset, binary_name: 'alpha.csv')
      create(:datafile, dataset: dataset, binary_name: 'beta.tsv')
    end

    it 'collects distinct reviewer/editor emails and includes the depositor in draft viewers' do
      expect(dataset.reviewer_emails).to eq(['reviewer@example.org'])
      expect(dataset.editor_emails).to contain_exactly('editor@example.org', 'reviewer@example.org')
      expect(dataset.view_emails).to contain_exactly('reviewer@example.org', 'editor@example.org')
      expect(dataset.draft_viewer_emails).to contain_exactly('reviewer@example.org', 'editor@example.org', 'depositor@example.org')
    end

    it 'returns funder names, codes, grants, and joined fulltext strings' do
      expect(dataset.funder_names).to contain_exactly('NSF', 'NIH')
      expect(dataset.funder_codes).to contain_exactly('nsf', 'nih')
      expect(dataset.grant_numbers).to contain_exactly('ABC-123', 'XYZ-987')
      expect(dataset.funder_names_fulltext).to eq('NSF NIH')
      expect(dataset.grant_numbers_fulltext).to eq('ABC-123 XYZ-987')
    end

    it 'returns fallback subject text when subject is blank' do
      expect(dataset.subject_text).to eq('None')
    end

    it 'returns filenames and extensions with joined fulltext values' do
      allow(dataset).to receive(:datafiles).and_return([
        double(bytestream_name: 'alpha.csv', file_extension: 'csv'),
        double(bytestream_name: 'beta.tsv', file_extension: 'tsv')
      ])

      expect(dataset.filenames).to contain_exactly('alpha.csv', 'beta.tsv')
      expect(dataset.filenames_fulltext).to eq('alpha.csv beta.tsv')
      expect(dataset.datafile_extensions).to contain_exactly('csv', 'tsv')
      expect(dataset.datafile_extensions_fulltext).to eq('csv tsv')
    end
  end
end
