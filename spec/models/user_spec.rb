require 'rails_helper'

RSpec.describe User, type: :model do
  describe '#system_admin?' do
    it 'returns true when uid is in configured admin netids' do
      user = build(:user, uid: 'alpha@illinois.edu', role: Databank::UserRole::DEPOSITOR)
      allow(IDB_CONFIG[:admin]).to receive(:[]).with(:netids).and_return('alpha, beta')

      expect(user.system_admin?).to be true
    end

    it 'returns true for admin role in test/development environments' do
      user = build(:user, uid: 'not-configured@illinois.edu', role: Databank::UserRole::ADMIN)
      allow(IDB_CONFIG[:admin]).to receive(:[]).with(:netids).and_return('alpha, beta')

      expect(user.system_admin?).to be true
    end

    it 'returns false when uid is not configured and role is not admin' do
      user = build(:user, uid: 'gamma@illinois.edu', role: Databank::UserRole::DEPOSITOR)
      allow(IDB_CONFIG[:admin]).to receive(:[]).with(:netids).and_return('alpha, beta')

      expect(user.system_admin?).to be false
    end
  end

  describe 'role predicates' do
    it 'recognizes admin, depositor, guest, and network reviewer roles' do
      user = build(:user, role: Databank::UserRole::ADMIN)
      expect(user.admin?).to be true

      user.role = Databank::UserRole::DEPOSITOR
      expect(user.depositor?).to be true

      user.role = Databank::UserRole::GUEST
      expect(user.guest?).to be true

      user.role = Databank::UserRole::NETWORK_REVIEWER
      expect(user.network_reviewer?).to be true
    end
  end

  describe '#datasets_user_can_view' do
    it 'returns all datasets for admin role' do
      user = build(:user, role: Databank::UserRole::ADMIN)
      admin_datasets = [double, double]

      allow(Dataset).to receive(:all).and_return(admin_datasets)

      expect(user.datasets_user_can_view(user: user)).to eq(admin_datasets)
    end

    it 'returns filtered union for depositor role and excludes forbidden states' do
      user = build(:user, provider: 'shibboleth', email: 'depositor@illinois.edu', role: Databank::UserRole::DEPOSITOR)
      public_ds = double(id: 1)
      owned_ds = double(id: 2)
      ability_ds = double(id: 3)
      blocked_hold = double(id: 4)
      blocked_pub = double(id: 5)

      allow(Dataset).to receive(:select).and_return([public_ds])
      allow(Dataset).to receive(:where).with(depositor_email: user.email).and_return([owned_ds])
      relation = double
      allow(UserAbility).to receive(:where).and_return(relation)
      allow(relation).to receive(:pluck).with(:resource_id).and_return([3, 4])
      allow(Dataset).to receive(:where).with(id: [3, 4]).and_return([ability_ds, blocked_hold])
      allow(Dataset).to receive(:where).with(hold_state: [Databank::PublicationState::TempSuppress::VERSION,
                                                          Databank::PublicationState::PermSuppress::METADATA]).and_return([blocked_hold])
      allow(Dataset).to receive(:where).with(publication_state: Databank::PublicationState::PermSuppress::METADATA).and_return([blocked_pub])

      result = user.datasets_user_can_view(user: user)

      expect(result).to contain_exactly(public_ds, owned_ds, ability_ds)
    end

    it 'returns metadata-public datasets for non-admin non-depositor roles' do
      user = build(:user, role: Databank::UserRole::GUEST)
      public_ds = [double, double]

      allow(Dataset).to receive(:select).and_return(public_ds)

      expect(user.datasets_user_can_view(user: user)).to eq(public_ds)
    end
  end

  describe '#datasets_user_can_edit' do
    it 'returns all datasets for admin role' do
      user = build(:user, role: Databank::UserRole::ADMIN)
      admin_datasets = [double, double]

      allow(Dataset).to receive(:all).and_return(admin_datasets)

      expect(user.datasets_user_can_edit(user: user)).to eq(admin_datasets)
    end

    it 'returns depositor editable datasets plus update abilities minus forbidden states' do
      user = build(:user, provider: 'shibboleth', email: 'depositor@illinois.edu', role: Databank::UserRole::DEPOSITOR)
      owned_ds = double(id: 10)
      ability_ds = double(id: 20)
      blocked_hold = double(id: 30)

      allow(Dataset).to receive(:where).with(depositor_email: user.email).and_return([owned_ds])
      relation = double
      allow(UserAbility).to receive(:where).and_return(relation)
      allow(relation).to receive(:pluck).with(:resource_id).and_return([20, 30])
      allow(Dataset).to receive(:where).with(id: [20, 30]).and_return([ability_ds, blocked_hold])
      allow(Dataset).to receive(:where).with(hold_state: [Databank::PublicationState::TempSuppress::VERSION,
                                                          Databank::PublicationState::PermSuppress::METADATA]).and_return([blocked_hold])
      allow(Dataset).to receive(:where).with(publication_state: Databank::PublicationState::PermSuppress::METADATA).and_return([])

      result = user.datasets_user_can_edit(user: user)

      expect(result).to contain_exactly(owned_ds, ability_ds)
    end

    it 'returns empty array for non-admin non-depositor roles' do
      user = build(:user, role: Databank::UserRole::GUEST)

      expect(user.datasets_user_can_edit(user: user)).to eq([])
    end
  end

  describe '.user_can?' do
    it 'returns false when user is nil' do
      expect(User.user_can?('Dataset', nil, 'read', nil)).to be false
    end

    it 'returns true for admin users' do
      user = build(:user, role: Databank::UserRole::ADMIN)

      expect(User.user_can?('Dataset', nil, 'destroy', user)).to be true
    end

    it 'returns true for depositor create/read/update/destroy without resource id' do
      user = build(:user, role: Databank::UserRole::DEPOSITOR)

      expect(User.user_can?('Dataset', nil, 'create', user)).to be true
      expect(User.user_can?('Dataset', nil, 'read', user)).to be true
      expect(User.user_can?('Dataset', nil, 'update', user)).to be true
      expect(User.user_can?('Dataset', nil, 'destroy', user)).to be true
    end

    it 'returns true when depositor owns requested dataset' do
      user = build(:user, role: Databank::UserRole::DEPOSITOR, email: 'owner@illinois.edu')
      dataset = double(depositor_email: 'owner@illinois.edu')
      allow(Dataset).to receive(:find).with(99).and_return(dataset)

      expect(User.user_can?('Dataset', 99, 'read', user)).to be true
      expect(User.user_can?('Dataset', 99, 'update', user)).to be true
      expect(User.user_can?('Dataset', 99, 'destroy', user)).to be true
    end

    it 'returns true when network reviewer can read curation network dataset' do
      user = build(:user, role: Databank::UserRole::NETWORK_REVIEWER)
      dataset = double(data_curation_network: true)
      allow(Dataset).to receive(:find).with(42).and_return(dataset)

      expect(User.user_can?('Dataset', 42, 'read', user)).to be true
    end

    it 'falls back to UserAbility relation check' do
      user = build(:user, provider: 'shibboleth', uid: 'abc@illinois.edu', role: Databank::UserRole::GUEST)
      relation = double(any?: true)
      expect(UserAbility).to receive(:where).with(user_provider: user.provider,
                                                 user_uid: user.uid,
                                                 resource_type: 'Dataset',
                                                 resource_id: 77,
                                                 ability: 'read').and_return(relation)

      expect(User.user_can?('Dataset', 77, 'read', user)).to be true
    end
  end

  describe '.curators and #associated_curator_ability' do
    it 'returns users with databank manage ability' do
      curator_ability = instance_double(UserAbility, user_uid: 'curator@illinois.edu')
      curator_user = create(:user, uid: 'curator@illinois.edu')

      allow(UserAbility).to receive(:where)
        .with(resource_type: 'Databank', ability: 'manage', resource_id: nil)
        .and_return([curator_ability])

      expect(User.curators).to eq([curator_user])
    end

    it 'returns the first matching associated curator ability for a user' do
      user = create(:user, provider: 'shibboleth', uid: 'curator@illinois.edu')
      ability = UserAbility.create!(user_provider: user.provider,
                                    user_uid: user.uid,
                                    resource_type: 'Databank',
                                    ability: 'manage',
                                    resource_id: nil)

      expect(user.associated_curator_ability).to eq(ability)
    end
  end

  describe '.from_omniauth / .create_with_omniauth / #update_with_omniauth' do
    let(:auth_hash) do
      {
        uid: 'netid@illinois.edu',
        'provider' => 'shibboleth',
        'uid' => 'netid@illinois.edu',
        'info' => {
          'email' => 'netid@illinois.edu',
          'name' => 'Test User',
          'role' => Databank::UserRole::GUEST
        }
      }
    end

    it 'returns nil when auth has no uid' do
      expect(User.from_omniauth({'provider' => 'shibboleth'})).to be_nil
    end

    it 'updates existing user in from_omniauth flow' do
      existing = create(:user, provider: 'shibboleth', uid: 'netid@illinois.edu', email: 'old@illinois.edu')
      allow(User).to receive(:find_by).with(provider: 'shibboleth', uid: 'netid@illinois.edu').and_return(existing)
      allow(existing).to receive(:update_with_omniauth).and_return(existing)

      expect(User.from_omniauth(auth_hash)).to eq(existing)
      expect(existing).to have_received(:update_with_omniauth).with(auth_hash)
    end

    it 'creates a new user from from_omniauth when no existing user is found' do
      created = create(:user, provider: 'shibboleth', uid: 'netid@illinois.edu')

      allow(User).to receive(:find_by).with(provider: 'shibboleth', uid: 'netid@illinois.edu').and_return(nil)
      allow(User).to receive(:create_with_omniauth).with(auth_hash).and_return(created)

      expect(User.from_omniauth(auth_hash)).to eq(created)
    end

    it 'creates user and applies computed role in shibboleth create flow' do
      allow(User).to receive(:user_role).and_return(Databank::UserRole::DEPOSITOR)

      created = User.create_with_omniauth(auth_hash)

      expect(created.provider).to eq('shibboleth')
      expect(created.uid).to eq('netid@illinois.edu')
      expect(created.username).to eq('netid')
      expect(created.role).to eq(Databank::UserRole::DEPOSITOR)
    end

    it 'updates attributes and recomputes username in update_with_omniauth' do
      user = create(:user, provider: 'shibboleth', uid: 'old@illinois.edu', email: 'old@illinois.edu', username: 'old')
      allow(User).to receive(:user_role).and_return(Databank::UserRole::DEPOSITOR)

      user.update_with_omniauth(auth_hash)

      expect(user.reload.email).to eq('netid@illinois.edu')
      expect(user.username).to eq('netid')
      expect(user.role).to eq(Databank::UserRole::DEPOSITOR)
    end
  end

  describe '#netid' do
    it 'returns the left side of the email' do
      user = build(:user, email: 'left.side@illinois.edu')

      expect(user.netid).to eq('left.side')
    end
  end

  describe '.user_role' do
    let(:base_auth) do
      {
        'provider' => 'shibboleth',
        'uid' => 'person@illinois.edu',
        'extra' => {
          'raw_info' => {
            'iTrustAffiliation' => 'student',
            'uiucEduStudentLevelCode' => '1G'
          }
        }
      }
    end

    it 'returns admin role when uid is in admin_uids' do
      allow(User).to receive(:admin_uids).and_return(['person@illinois.edu'])

      expect(User.user_role(base_auth)).to eq(Databank::UserRole::ADMIN)
    end

    it 'returns depositor for existing user with create ability' do
      allow(User).to receive(:admin_uids).and_return([])
      existing = create(:user, provider: 'shibboleth', uid: 'person@illinois.edu')
      allow(UserAbility).to receive(:user_can?).with('Dataset', nil, 'create', existing).and_return(true)

      expect(User.user_role(base_auth)).to eq(Databank::UserRole::DEPOSITOR)
    end

    it 'returns no_deposit for undergraduate student affiliations' do
      allow(User).to receive(:admin_uids).and_return([])
      auth = base_auth.deep_dup
      auth['extra']['raw_info']['iTrustAffiliation'] = 'student'
      auth['extra']['raw_info']['uiucEduStudentLevelCode'] = '1U'

      expect(User.user_role(auth)).to eq(Databank::UserRole::NO_DEPOSIT)
    end

    it 'returns depositor for graduate student affiliations' do
      allow(User).to receive(:admin_uids).and_return([])
      auth = base_auth.deep_dup
      auth['extra']['raw_info']['iTrustAffiliation'] = 'student'
      auth['extra']['raw_info']['uiucEduStudentLevelCode'] = '1G'

      expect(User.user_role(auth)).to eq(Databank::UserRole::DEPOSITOR)
    end

    it 'returns depositor for staff affiliation' do
      allow(User).to receive(:admin_uids).and_return([])
      auth = base_auth.deep_dup
      auth['extra']['raw_info']['iTrustAffiliation'] = 'staff;affiliate'

      expect(User.user_role(auth)).to eq(Databank::UserRole::DEPOSITOR)
    end

    it 'returns no_deposit and notifies on missing affiliation data' do
      allow(User).to receive(:admin_uids).and_return([])
      auth = base_auth.deep_dup
      auth['extra']['raw_info']['iTrustAffiliation'] = nil
      mail = double
      allow(mail).to receive(:deliver_now)
      expect(DatabankMailer).to receive(:error).and_return(mail)

      expect(User.user_role(auth)).to eq(Databank::UserRole::NO_DEPOSIT)
    end

    it 'returns no_deposit and notifies on unexpected split affiliation shape' do
      allow(User).to receive(:admin_uids).and_return([])
      auth = base_auth.deep_dup
      split_source = Class.new do
        def split(*)
          []
        end
      end.new
      auth['extra']['raw_info']['iTrustAffiliation'] = split_source
      mail = double
      allow(mail).to receive(:deliver_now)
      allow(Rails.logger).to receive(:warn)
      expect(DatabankMailer).to receive(:error).and_return(mail)

      expect(User.user_role(auth)).to eq(Databank::UserRole::NO_DEPOSIT)
      expect(Rails.logger).to have_received(:warn).with(/unexpected auth:/)
    end
  end

  describe '.system_user and .admin_uids' do
    it 'returns an existing system user when present' do
      system = create(:user, provider: 'system', uid: IDB_CONFIG[:system_user_email], email: IDB_CONFIG[:system_user_email])

      expect(User.system_user).to eq(system)
    end

    it 'creates the system user when missing' do
      User.where(provider: 'system', uid: IDB_CONFIG[:system_user_email]).delete_all

      system = User.system_user

      expect(system.provider).to eq('system')
      expect(system.uid).to eq(IDB_CONFIG[:system_user_email])
      expect(system.name).to eq(IDB_CONFIG[:system_user_name])
      expect(system.email).to eq(IDB_CONFIG[:system_user_email])
      expect(system.username).to eq(IDB_CONFIG[:system_user_name])
      expect(system.role).to eq('admin')
    end

    it 'combines config admins and databank manage abilities in admin_uids' do
      allow(IDB_CONFIG[:admin]).to receive(:[]).with(:netids).and_return('alpha, beta')
      ability = UserAbility.create!(resource_type: 'Databank',
                                    ability: 'manage',
                                    resource_id: nil,
                                    user_provider: 'shibboleth',
                                    user_uid: 'curator@illinois.edu')
      expect(ability).to be_present

      result = User.admin_uids

      expect(result).to include('alpha@illinois.edu', 'beta@illinois.edu', 'curator@illinois.edu')
    end
  end
end
