require 'rails_helper'

RSpec.describe Dataset::Versionable, type: :model do
  describe '#add_version_metadata_copy' do
    it 'returns true when title already matches previous version title' do
      previous = create(:dataset, title: 'Shared Title')
      dataset = create(:dataset, title: 'Shared Title')

      expect(dataset.add_version_metadata_copy(previous: previous)).to be true
    end

    it 'copies metadata and bumps version details when title differs' do
      previous = create(
        :dataset,
        title: 'Previous Title',
        identifier: '10.13012/B2IDB-1111111_V3',
        dataset_version: '3',
        publisher: 'University of Illinois Urbana-Champaign',
        description: 'prior description',
        license: 'CCBY4',
        keywords: 'alpha;beta',
        subject: 'Engineering',
        org_creators: true,
        is_test: true
      )
      dataset = create(:dataset, title: 'New Draft Title', dataset_version: '1')

      expect(dataset.add_version_metadata_copy(previous: previous)).to be true
      dataset.reload

      expect(dataset.title).to eq('Previous Title')
      expect(dataset.identifier).to eq('10.13012/B2IDB-1111111_V4')
      expect(dataset.dataset_version).to eq('4')
      expect(dataset.publication_state).to eq(Databank::PublicationState::TempSuppress::VERSION)
      expect(dataset.hold_state).to eq(Databank::PublicationState::TempSuppress::VERSION)
      expect(dataset.embargo).to eq(Databank::PublicationState::Embargo::NONE)
      expect(dataset.is_test).to be true
      expect(dataset.org_creators).to be true
    end
  end

  describe '#version copy tracking' do
    let(:dataset) { create(:dataset) }

    it 'returns true only when all version files are complete' do
      allow(dataset).to receive(:version_files).and_return([
        instance_double(VersionFile, complete?: true),
        instance_double(VersionFile, complete?: true)
      ])
      expect(dataset.version_copies_complete?).to be true

      allow(dataset).to receive(:version_files).and_return([
        instance_double(VersionFile, complete?: true),
        instance_double(VersionFile, complete?: false)
      ])
      expect(dataset.version_copies_complete?).to be false
    end

    it 'returns true when at least one version file is initiated' do
      allow(dataset).to receive(:version_files).and_return([
        instance_double(VersionFile, initiated?: false),
        instance_double(VersionFile, initiated?: true)
      ])

      expect(dataset.version_copies_initiated?).to be true
    end

    it 'marks each selected version file as initiated' do
      v1 = instance_double(VersionFile)
      v2 = instance_double(VersionFile)
      expect(v1).to receive(:update_attribute).with(:initiated, true)
      expect(v2).to receive(:update_attribute).with(:initiated, true)

      dataset.mark_version_files_initiated(files_to_copy: [v1, v2])
    end
  end

  describe '#related_version_entry_hash' do
    it 'normalizes missing fields and uses default publication date text' do
      dataset = build(:dataset, dataset_version: nil, identifier: nil, version_comment: nil, release_date: nil)
      hash = dataset.related_version_entry_hash

      expect(hash[:version]).to eq(1)
      expect(hash[:doi]).to eq('not yet set')
      expect(hash[:version_comment]).to eq('')
      expect(hash[:publication_date]).to eq('not yet set')
    end
  end

  describe '#has_newer_version?' do
    it 'returns false when there is no latest published version' do
      dataset = create(:dataset, dataset_version: '2')
      dataset.version_group = instance_double(VersionGroup, latest_published_version: nil)

      expect(dataset.has_newer_version?).to be false
    end

    it 'returns true when second entry is newer and first entry is draft-like' do
      dataset = create(:dataset, dataset_version: '2')
      dataset.version_group = instance_double(
        VersionGroup,
        latest_published_version: Object.new,
        group_hash: {
          entries: [
            { version: 3, publication_state: Databank::PublicationState::DRAFT },
            { version: 4, publication_state: Databank::PublicationState::RELEASED }
          ]
        }
      )

      expect(dataset.has_newer_version?).to be true
    end
  end

  describe '#is_most_recent_version and #eligible_for_version?' do
    it 'returns false for draft datasets regardless of version group' do
      dataset = create(:dataset, publication_state: Databank::PublicationState::DRAFT, dataset_version: '1')

      expect(dataset.is_most_recent_version).to be false
    end

    it 'returns true for eligible published dataset with no next version' do
      dataset = create(:dataset, publication_state: Databank::PublicationState::RELEASED, dataset_version: '2')
      allow(dataset).to receive(:is_most_recent_version).and_return(true)
      allow(dataset).to receive(:next_idb_dataset).and_return(nil)

      expect(dataset.eligible_for_version?).to be true
    end
  end

  describe '#add_version_files' do
    it 'creates one version file record per previous dataset datafile' do
      previous = create(:dataset)
      dataset = create(:dataset)
      datafile1 = instance_double(Datafile, id: 101)
      datafile2 = instance_double(Datafile, id: 202)

      allow(dataset).to receive(:version_files).and_return([])
      allow(previous).to receive(:datafiles).and_return([datafile1, datafile2])
      expect(VersionFile).to receive(:create).with(dataset_id: dataset.id, datafile_id: 101, selected: false)
      expect(VersionFile).to receive(:create).with(dataset_id: dataset.id, datafile_id: 202, selected: false)

      dataset.add_version_files(previous: previous)
    end
  end

  describe '#add_version_relationships' do
    it 'creates forward and backward related material entries' do
      previous = create(:dataset, identifier: '10.13012/B2IDB-2222222_V1')
      dataset = create(:dataset, identifier: '10.13012/B2IDB-2222222_V2')
      allow(previous).to receive(:plain_text_citation).and_return('previous citation')
      allow(dataset).to receive(:plain_text_citation).and_return('new citation')

      expect { dataset.add_version_relationships(previous: previous) }.to change(RelatedMaterial, :count).by(2)

      expect(dataset.related_materials.find_by(datacite_list: Databank::Relationship::NEW_VERSION_OF).uri)
        .to eq(previous.identifier)
      expect(previous.related_materials.find_by(datacite_list: Databank::Relationship::PREVIOUS_VERSION_OF).uri)
        .to eq(dataset.identifier)
    end
  end
end
