require 'rails_helper'

RSpec.describe UserAbility, type: :model do
  let(:dataset) { create(:dataset) }
  let(:user) { create(:user, email: 'editor@illinois.edu', provider: 'shibboleth', uid: 'editor@illinois.edu') }

  describe '#deposit_exception?' do
    it 'returns true for a dataset-create global ability' do
      ua = UserAbility.new(resource_type: 'Dataset', resource_id: nil, ability: 'create')
      expect(ua.deposit_exception?).to be true
    end

    it 'returns false when resource_id is set' do
      ua = UserAbility.new(resource_type: 'Dataset', resource_id: 1, ability: 'create')
      expect(ua.deposit_exception?).to be false
    end

    it 'returns false when resource_type is not Dataset' do
      ua = UserAbility.new(resource_type: 'Databank', resource_id: nil, ability: 'create')
      expect(ua.deposit_exception?).to be false
    end

    it 'returns false when ability is not create' do
      ua = UserAbility.new(resource_type: 'Dataset', resource_id: nil, ability: 'read')
      expect(ua.deposit_exception?).to be false
    end
  end

  describe '#curator?' do
    it 'returns true for a global Databank manage ability' do
      ua = UserAbility.new(resource_type: 'Databank', resource_id: nil, ability: 'manage')
      expect(ua.curator?).to be true
    end

    it 'returns false when resource_id is set' do
      ua = UserAbility.new(resource_type: 'Databank', resource_id: 1, ability: 'manage')
      expect(ua.curator?).to be false
    end

    it 'returns false when ability is not manage' do
      ua = UserAbility.new(resource_type: 'Databank', resource_id: nil, ability: 'read')
      expect(ua.curator?).to be false
    end
  end

  describe '#trim_values' do
    it 'strips whitespace from string fields on save' do
      ua = UserAbility.create!(
        resource_type: '  Dataset  ',
        resource_id: dataset.id,
        user_provider: ' shibboleth ',
        user_uid: ' padded@illinois.edu ',
        ability: ' read '
      )
      expect(ua.resource_type).to eq('Dataset')
      expect(ua.user_provider).to eq('shibboleth')
      expect(ua.user_uid).to eq('padded@illinois.edu')
      expect(ua.ability).to eq('read')
    end
  end

  describe '.user_can?' do
    it 'returns false when user is nil' do
      expect(UserAbility.user_can?('Dataset', dataset.id, 'read', nil)).to be false
    end

    it 'returns false when no matching ability record exists' do
      expect(UserAbility.user_can?('Dataset', dataset.id, 'read', user)).to be false
    end

    it 'returns true when a matching ability record exists' do
      UserAbility.create!(resource_type: 'Dataset', resource_id: dataset.id,
                          user_provider: user.provider, user_uid: user.uid, ability: 'read')
      expect(UserAbility.user_can?('Dataset', dataset.id, 'read', user)).to be true
    end
  end

  describe '.grant_deposit_exception / .revoke_deposit_exception' do
    it 'creates a global dataset create ability' do
      expect { UserAbility.grant_deposit_exception(user: user) }
        .to change(UserAbility, :count).by(1)

      ua = UserAbility.last
      expect(ua.resource_type).to eq('Dataset')
      expect(ua.ability).to eq('create')
      expect(ua.user_uid).to eq(user.uid)
    end

    it 'destroys the deposit exception record' do
      UserAbility.create!(resource_type: 'Dataset', resource_id: nil,
                          user_provider: user.provider, user_uid: user.uid, ability: 'create')

      expect { UserAbility.revoke_deposit_exception(user: user) }
        .to change(UserAbility, :count).by(-1)
    end
  end

  describe '.update_permissions' do
    it 'raises when the dataset is not found' do
      expect { UserAbility.update_permissions('missing-key') }
        .to raise_error(StandardError, /dataset not found/)
    end

    it 'adds reviewer and editor abilities for new users' do
      expect {
        UserAbility.update_permissions(dataset.key, ['reviewer@illinois.edu'], ['editor@illinois.edu'])
      }.to change(UserAbility, :count).by(5)

      expect(UserAbility.where(resource_type: 'Dataset', resource_id: dataset.id,
                               user_uid: 'editor@illinois.edu', ability: 'update').exists?).to be true
    end

    it 'removes stale reviewer abilities when absent from form list' do
      UserAbility.create!(resource_type: 'Dataset', resource_id: dataset.id,
                          user_provider: 'shibboleth', user_uid: 'old@illinois.edu', ability: 'view_files')

      expect {
        UserAbility.update_permissions(dataset.key, [], [])
      }.to change(UserAbility, :count).by(-1)
    end
  end

  describe '.add_to_editors / .remove_from_editors' do
    it 'does nothing when user is already an editor' do
      UserAbility.create!(resource_type: 'Dataset', resource_id: dataset.id,
                          user_provider: 'shibboleth', user_uid: user.email, ability: 'update')

      expect { UserAbility.add_to_editors(dataset: dataset, email: user.email) }
        .not_to change(UserAbility, :count)
    end

    it 'adds read, view_files, and update abilities when not already an editor' do
      expect { UserAbility.add_to_editors(dataset: dataset, email: 'new@illinois.edu') }
        .to change(UserAbility, :count).by(3)
    end

    it 'does nothing when user is not currently an editor' do
      expect { UserAbility.remove_from_editors(dataset: dataset, email: user.email) }
        .not_to change(UserAbility, :count)
    end

    it 'removes read, view_files, and update abilities when currently an editor' do
      %w[read view_files update].each do |ability|
        UserAbility.create!(resource_type: 'Dataset', resource_id: dataset.id,
                            user_provider: 'shibboleth', user_uid: user.email, ability: ability)
      end

      expect { UserAbility.remove_from_editors(dataset: dataset, email: user.email) }
        .to change(UserAbility, :count).by(-3)
    end
  end

  describe '.grant' do
    it 'returns false for a non-Illinois non-registered email' do
      expect(UserAbility.grant(dataset: dataset, email: 'outside@example.org', ability: :read)).to be false
    end

    it 'creates a shibboleth ability for an Illinois email without a user record' do
      expect {
        UserAbility.grant(dataset: dataset, email: 'faculty@illinois.edu', ability: :read)
      }.to change(UserAbility, :count).by(1)

      ua = UserAbility.last
      expect(ua.user_provider).to eq('shibboleth')
      expect(ua.user_uid).to eq('faculty@illinois.edu')
    end

    it 'delegates to grant_external for a known user' do
      expect(UserAbility).to receive(:grant_external).with(dataset: dataset, user: user, ability: :read)
      UserAbility.grant(dataset: dataset, email: user.email, ability: :read)
    end

    it 'does not duplicate an existing Illinois email ability' do
      UserAbility.grant(dataset: dataset, email: 'faculty@illinois.edu', ability: :read)
      expect {
        UserAbility.grant(dataset: dataset, email: 'faculty@illinois.edu', ability: :read)
      }.not_to change(UserAbility, :count)
    end
  end

  describe '.revoke' do
    it 'returns false for a non-Illinois non-registered email' do
      expect(UserAbility.revoke(dataset: dataset, email: 'outside@example.org', ability: :read)).to be false
    end

    it 'destroys an existing Illinois shibboleth ability' do
      UserAbility.create!(resource_type: 'Dataset', resource_id: dataset.id,
                          user_provider: 'shibboleth', user_uid: 'faculty@illinois.edu', ability: 'read')

      expect {
        UserAbility.revoke(dataset: dataset, email: 'faculty@illinois.edu', ability: :read)
      }.to change(UserAbility, :count).by(-1)
    end

    it 'delegates to revoke_external for a known user' do
      expect(UserAbility).to receive(:revoke_external).with(dataset: dataset, user: user, ability: :read)
      UserAbility.revoke(dataset: dataset, email: user.email, ability: :read)
    end
  end
end
