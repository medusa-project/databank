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
    testers = IDB_CONFIG[:testers].split(",").collect {|x| x.strip || x}
    testers.each do |email|
      name = email
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
      identity.name = name
      identity.activated = true
      identity.activated_at = Time.zone.now
      identity.save!
    end
  end

end