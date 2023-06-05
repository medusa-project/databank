namespace :local_identity do
  desc 'generate dev local identities'
  task :make_admins => :environment do
    # create local identity accounts for admins
    admins = IDB_CONFIG[:admin][:netids].split(",").collect {|x| x.strip || x}
    admins.each do |netid|
      email = "#{netid}@illinois.edu"
      name = "admin #{netid}"
      invitee = Invitee.find_or_create_by(email: email)
      invitee.role = Databank::UserRole::ADMIN
      invitee.expires_at = Time.zone.now + 1.years
      invitee.save!
      identity = Identity.find_or_create_by(email: email)
      salt = BCrypt::Engine.generate_salt
      localpass = IDB_CONFIG[:admin][:localpass]
      encrypted_password = BCrypt::Engine.hash_secret(localpass, salt)
      identity.password_digest = encrypted_password
      identity.update(password: localpass, password_confirmation: localpass)
      identity.name = name
      identity.activated = true
      identity.activated_at = Time.zone.now
      identity.save!
    end
  end

  desc 'make tester accounts'
  task :make_testers => :environment do
    roles = [
      Databank::UserRole::ADMIN,
      Databank::UserRole::DEPOSITOR,
      Databank::UserRole::GUEST,
      Databank::UserRole::NO_DEPOSIT,
      Databank::UserRole::NETWORK_REVIEWER,
      Databank::UserRole::PUBLISHER_REVIEWER,
      Databank::UserRole::CREATOR
    ]
    roles.each do |role|
      Identity.create_test_account(name: "#{role}1", email: "#{role}1@mailinator.com", role: role)
      Identity.create_test_account(name: "#{role}2", email: "#{role}2@mailinator.com", role: role)
    end
  end

  desc 'make special character account(s)'
  task :make_edge_case => :environment do
    # with apostrophe in name
    email = "idb_test@mailinator.com"
    invitee = Invitee.find_or_create_by(email: email)
    invitee.role = Databank::UserRole::DEPOSITOR
    invitee.expires_at = Time.zone.now + 1.years
    invitee.save!
    identity = Identity.find_or_create_by(email: email)
    salt = BCrypt::Engine.generate_salt
    localpass = IDB_CONFIG[:admin][:localpass]
    encrypted_password = BCrypt::Engine.hash_secret(localpass, salt)
    identity.password_digest = encrypted_password
    identity.update(password: localpass, password_confirmation: localpass)
    identity.name = "Joy O'Keefe"
    identity.activated = true
    identity.activated_at = Time.zone.now
    identity.save!
  end

end