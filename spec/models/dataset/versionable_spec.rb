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

  describe '#destroy_relationship_with_previous_version' do
    it 'returns true when there is no previous dataset' do
      dataset = create(:dataset)

      allow(dataset).to receive(:previous_idb_dataset).and_return(nil)

      expect(dataset.destroy_relationship_with_previous_version).to be true
    end

    it 'destroys the previous-version relation when present' do
      dataset = create(:dataset)
      relation = instance_double(RelatedMaterial)
      previous = instance_double(Dataset)
      relations = instance_double(ActiveRecord::Associations::CollectionProxy)

      allow(dataset).to receive(:previous_idb_dataset).and_return(previous)
      allow(previous).to receive(:related_materials).and_return(relations)
      allow(relations).to receive(:find_by)
        .with(datacite_list: Databank::Relationship::PREVIOUS_VERSION_OF)
        .and_return(relation)
      expect(relation).to receive(:destroy)

      dataset.destroy_relationship_with_previous_version
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

  describe '#ensure_version_group and #update_version_group' do
    it 'memoizes version group and can refresh it' do
      dataset = create(:dataset)
      first_group = instance_double(VersionGroup)
      second_group = instance_double(VersionGroup)

      expect(VersionGroup).to receive(:new).with(dataset).once.and_return(first_group)
      dataset.ensure_version_group
      dataset.ensure_version_group
      expect(dataset.version_group).to eq(first_group)

      expect(VersionGroup).to receive(:new).with(dataset).and_return(second_group)
      dataset.update_version_group

      expect(dataset.version_group).to eq(second_group)
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

    it 'returns false when there is only one entry in the version group' do
      dataset = create(:dataset, dataset_version: '2')
      dataset.version_group = instance_double(
        VersionGroup,
        latest_published_version: Object.new,
        group_hash: { entries: [{ version: 2, publication_state: Databank::PublicationState::RELEASED }] }
      )

      expect(dataset.has_newer_version?).to be false
    end

    it 'returns false when dataset version is not positive' do
      dataset = create(:dataset, dataset_version: '0')
      dataset.version_group = instance_double(
        VersionGroup,
        latest_published_version: Object.new,
        group_hash: {
          entries: [
            { version: 3, publication_state: Databank::PublicationState::RELEASED },
            { version: 2, publication_state: Databank::PublicationState::RELEASED }
          ]
        }
      )

      expect(dataset.has_newer_version?).to be false
    end
  end

  describe '#version_eligible_for_review?' do
    it 'returns true only for version-suppressed datasets without a hold' do
      dataset = create(
        :dataset,
        publication_state: Databank::PublicationState::TempSuppress::VERSION,
        hold_state: Databank::PublicationState::TempSuppress::NONE
      )

      expect(dataset.version_eligible_for_review?).to be true

      dataset.hold_state = Databank::PublicationState::TempSuppress::VERSION
      expect(dataset.version_eligible_for_review?).to be false
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

    it 'returns true when it is the only entry in the version group' do
      dataset = create(:dataset, publication_state: Databank::PublicationState::RELEASED, dataset_version: '2')
      dataset.version_group = instance_double(
        VersionGroup,
        group_hash: { entries: [{ version: 2, publication_state: Databank::PublicationState::RELEASED }] }
      )

      expect(dataset.is_most_recent_version).to be true
    end

    it 'uses the second entry when the first entry is draft-like' do
      dataset = create(:dataset, publication_state: Databank::PublicationState::RELEASED, dataset_version: '4')
      dataset.version_group = instance_double(
        VersionGroup,
        group_hash: {
          entries: [
            { version: 5, publication_state: Databank::PublicationState::DRAFT },
            { version: 4, publication_state: Databank::PublicationState::RELEASED }
          ]
        }
      )

      expect(dataset.is_most_recent_version).to be true
    end

    it 'returns false when a newer published entry exists' do
      dataset = create(:dataset, publication_state: Databank::PublicationState::RELEASED, dataset_version: '2')
      dataset.version_group = instance_double(
        VersionGroup,
        group_hash: {
          entries: [
            { version: 3, publication_state: Databank::PublicationState::RELEASED },
            { version: 2, publication_state: Databank::PublicationState::RELEASED }
          ]
        }
      )

      expect(dataset.is_most_recent_version).to be false
    end

    it 'returns false for eligible_for_version when a next version exists' do
      dataset = create(:dataset, publication_state: Databank::PublicationState::RELEASED, dataset_version: '2')

      allow(dataset).to receive(:is_most_recent_version).and_return(true)
      allow(dataset).to receive(:next_idb_dataset).and_return(instance_double(Dataset))

      expect(dataset.eligible_for_version?).to be false
    end
  end

  describe '#send_version_request_emails' do
    it 'logs and suppresses syntax errors from the mailer' do
      dataset = create(:dataset)
      request_mail = instance_double(ActionMailer::MessageDelivery)
      logger = Rails.logger

      allow(DatabankMailer).to receive(:request_version).with(dataset_key: dataset.key).and_return(request_mail)
      allow(request_mail).to receive(:deliver_now).and_raise(Net::SMTPSyntaxError.new('bad address'))
      allow(Rails).to receive(:logger).and_return(logger)
      expect(logger).to receive(:warn).with('bad address')
      expect(logger).to receive(:warn).with(/could not version request mail/)

      expect { dataset.send_version_request_emails }.not_to raise_error
    end

    it 're-raises unexpected errors after logging them' do
      dataset = create(:dataset)
      request_mail = instance_double(ActionMailer::MessageDelivery)
      logger = Rails.logger

      allow(DatabankMailer).to receive(:request_version).with(dataset_key: dataset.key).and_return(request_mail)
      allow(request_mail).to receive(:deliver_now).and_raise(StandardError.new('boom'))
      allow(Rails).to receive(:logger).and_return(logger)
      expect(logger).to receive(:warn).with('error while trying to send version_request_emails boom')

      expect { dataset.send_version_request_emails }.to raise_error(StandardError, 'boom')
    end
  end

  describe '#add_version_nested_objects' do
    it 'returns true when creators already exist on the new dataset' do
      previous = create(:dataset)
      dataset = create(:dataset)

      create(:creator, dataset: dataset)

      expect(dataset.add_version_nested_objects(previous: previous)).to be true
    end

    it 'copies creators, funders, and only non-version related materials' do
      previous = create(:dataset)
      dataset = create(:dataset)

      create(:creator, dataset: previous, given_name: 'Avery', family_name: 'Smith')
      create(:funder, dataset: previous, name: 'DOE')
      keep_material = create(:related_material, dataset: previous, datacite_list: Databank::Relationship::SUPPLEMENT_TO)
      create(:related_material, dataset: previous, datacite_list: Databank::Relationship::NEW_VERSION_OF)
      create(:related_material, dataset: previous, datacite_list: Databank::Relationship::PREVIOUS_VERSION_OF)
      previous.reload

      expect(dataset.add_version_nested_objects(previous: previous)).to be true
      dataset.reload

      expect(dataset.creators.pluck(:given_name, :family_name)).to include(['Avery', 'Smith'])
      expect(dataset.funders.pluck(:name)).to include('DOE')
      expect(dataset.related_materials.pluck(:datacite_list)).to eq([keep_material.datacite_list])
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

    it 'returns true when version files already exist' do
      previous = create(:dataset)
      dataset = create(:dataset)

      allow(dataset).to receive(:version_files).and_return([instance_double(VersionFile)])

      expect(dataset.add_version_files(previous: previous)).to be true
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

    it 'returns true when the new-version relation already exists on the current dataset' do
      previous = create(:dataset, identifier: '10.13012/B2IDB-2222222_V1')
      dataset = create(:dataset, identifier: '10.13012/B2IDB-2222222_V2')
      create(:related_material, dataset: dataset, datacite_list: Databank::Relationship::NEW_VERSION_OF)

      expect(dataset.add_version_relationships(previous: previous)).to be true
    end
  end

  describe '#copy_version_files' do
    let(:dataset) { create(:dataset) }

    it 'returns true when all selected files are already complete' do
      allow(dataset).to receive(:version_files).and_return([
        instance_double(VersionFile, selected: true, complete?: true),
        instance_double(VersionFile, selected: false, complete?: false)
      ])

      expect(dataset.copy_version_files_without_delay).to be true
    end

    it 'copies incomplete selected files and sends completion mail in server envs' do
      file_to_copy = instance_double(VersionFile, selected: true, complete?: false)
      complete_file = instance_double(VersionFile, selected: true, complete?: true)
      mail = instance_double(ActionMailer::MessageDelivery)

      allow(dataset).to receive(:version_files).and_return([file_to_copy, complete_file])
      allow(Application).to receive(:server_envs).and_return([Rails.env])
      allow(DatabankMailer).to receive(:notify_version_copy_complete).with(dataset_key: dataset.key).and_return(mail)
      expect(file_to_copy).to receive(:copy_file)
      expect(mail).to receive(:deliver_now)

      dataset.copy_version_files_without_delay
    end

    it 'logs instead of mailing outside server envs' do
      file_to_copy = instance_double(VersionFile, selected: true, complete?: false)
      logger = Rails.logger

      allow(dataset).to receive(:version_files).and_return([file_to_copy])
      allow(Application).to receive(:server_envs).and_return([])
      allow(Rails).to receive(:logger).and_return(logger)
      expect(file_to_copy).to receive(:copy_file)
      expect(logger).to receive(:warn).with(/skipping version copy email/)

      dataset.copy_version_files_without_delay
    end
  end

  describe '#is_unconfirmed_version?' do
    it 'returns true when either publication or hold state marks a version' do
      dataset = create(:dataset, publication_state: Databank::PublicationState::TempSuppress::VERSION)
      expect(dataset.is_unconfirmed_version?).to be true

      dataset.publication_state = Databank::PublicationState::RELEASED
      dataset.hold_state = Databank::PublicationState::TempSuppress::VERSION
      expect(dataset.is_unconfirmed_version?).to be true

      dataset.hold_state = Databank::PublicationState::TempSuppress::NONE
      expect(dataset.is_unconfirmed_version?).to be false
    end
  end

  describe '#previous_idb_dataset and #next_idb_dataset' do
    it 'finds the previous dataset from the new-version relation' do
      previous = create(:dataset, identifier: '10.13012/B2IDB-3333333_V1')
      dataset = create(:dataset)
      create(:related_material, dataset: dataset, datacite_list: Databank::Relationship::NEW_VERSION_OF, uri: previous.identifier)

      expect(dataset.previous_idb_dataset).to eq(previous)
    end

    it 'returns nil when the next linked dataset is still version-suppressed' do
      next_dataset = create(:dataset, identifier: '10.13012/B2IDB-4444444_V2')
      dataset = create(
        :dataset,
        identifier: '10.13012/B2IDB-4444444_V1',
        publication_state: Databank::PublicationState::TempSuppress::VERSION
      )
      create(:related_material, dataset: dataset, datacite_list: Databank::Relationship::PREVIOUS_VERSION_OF, uri: next_dataset.identifier)

      expect(dataset.next_idb_dataset).to be_nil
    end

    it 'finds the next dataset when the related dataset is published' do
      next_dataset = create(:dataset, identifier: '10.13012/B2IDB-5555555_V2', publication_state: Databank::PublicationState::RELEASED)
      dataset = create(:dataset, identifier: '10.13012/B2IDB-5555555_V1', publication_state: Databank::PublicationState::RELEASED)
      create(:related_material, dataset: dataset, datacite_list: Databank::Relationship::PREVIOUS_VERSION_OF, uri: next_dataset.identifier)

      expect(dataset.next_idb_dataset).to eq(next_dataset)
    end
  end
end
