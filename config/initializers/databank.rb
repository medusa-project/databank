require 'aws-sdk'
require 'aws-sdk-s3'
require 'tus/storage/s3'
require 'tus/storage/filesystem'

VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i

PRODUCTION_PREFIXES = ["10.13012", "10.25988"]

DEMO_PREFIXES = ["10.26123"]

TEST_PREFIXES = ["10.70114"]

IDB_CONFIG = YAML.load(ERB.new(File.read(File.join(Rails.root, 'config', 'databank.yml'))).result)
STORAGE_CONFIG = YAML.load(ERB.new(File.read(File.join(Rails.root, 'config', 'medusa_storage.yml'))).result)[Rails.env]

Application.read_only_message = Datafile.read_only_message
Application.read_only_msg_middle = Datafile.read_only_msg_middle
Application.storage_manager = StorageManager.new
# Initializes a Markdown parser
Application.markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)

Tus::Server.opts[:max_size] = 2 * 1024*1024*1024*1024 # 2TB

if IDB_CONFIG[:aws][:s3_mode] == true

  Aws.config.update({
                        region: IDB_CONFIG[:aws][:region],
                        credentials: Aws::Credentials.new(IDB_CONFIG[:aws][:access_key_id], IDB_CONFIG[:aws][:secret_access_key])
                    })

  Application.aws_signer = Aws::S3::Presigner.new

  Application.aws_client = Aws::S3::Client.new

  Tus::Server.opts[:storage] = Tus::Storage::S3.new(prefix: 'uploads',
      bucket:            STORAGE_CONFIG[:storage][0][:bucket], # required
      access_key_id:     IDB_CONFIG[:aws][:access_key_id],
      secret_access_key: IDB_CONFIG[:aws][:secret_access_key],
      region:            IDB_CONFIG[:aws][:region],
      )

else

  Tus::Server.opts[:storage] = Tus::Storage::Filesystem.new(STORAGE_CONFIG[:storage][0][:path] )

end

if Rails.env.development?
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
    identity.update_attributes(password: localpass, password_confirmation: localpass)
    identity.name = name
    identity.activated = true
    identity.activated_at = Time.zone.now
    identity.save!
  end

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
    identity.update_attributes(password: localpass, password_confirmation: localpass)
    identity.name = name
    identity.activated = true
    identity.activated_at = Time.zone.now
    identity.save!
  end

end

