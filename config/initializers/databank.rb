require 'aws-sdk'
require 'aws-sdk-s3'
require 'tus/storage/s3'
require 'tus/storage/filesystem'

VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i

PRODUCTION_PREFIXES = ["10.13012", "10.25988"]

DEMO_PREFIXES = ["10.26123"]

TEST_PREFIXES = ["10.70114"]

GLOBUS_CONFIG = YAML.load_file(Rails.root.join('config', 'globus.yml'))[Rails.env]
METRICS_CONFIG = YAML.load(ERB.new(File.read(File.join(Rails.root, "config/metrics.yml"))).result)

# Initializes a Markdown parser
Application.markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)

Tus::Server.opts[:max_size] = 2 * 1024**4 # 2TB

if IDB_CONFIG[:aws][:s3_mode] == true

  Aws.config.update({region: IDB_CONFIG[:aws][:region]})

  # Aws.config.update({
  #                       region: IDB_CONFIG[:aws][:region],
  #                       credentials: Aws::Credentials.new(IDB_CONFIG[:aws][:access_key_id], IDB_CONFIG[:aws][:secret_access_key])
  #                   })

  Application.aws_signer = Aws::S3::Presigner.new

  Application.aws_client = Aws::S3::Client.new

  Tus::Server.opts[:storage] = Tus::Storage::S3.new(prefix: 'uploads',
      bucket:            STORAGE_CONFIG[:storage][0][:bucket], # required
      region:            IDB_CONFIG[:aws][:region])

  # Tus::Server.opts[:storage] = Tus::Storage::S3.new(prefix: 'uploads',
  #                                                   bucket:            STORAGE_CONFIG[:storage][0][:bucket], # required
  #                                                   access_key_id:     IDB_CONFIG[:aws][:access_key_id],
  #                                                   secret_access_key: IDB_CONFIG[:aws][:secret_access_key],
  #                                                   region:            IDB_CONFIG[:aws][:region],
  #                                                   )
elsif IDB_CONFIG[:aws][:s3_mode] == "local"

  Aws.config.update({region: IDB_CONFIG[:aws][:region]})
  Aws.config.update({access_key_id: 'minioadmin'})
  Aws.config.update({secret_access_key: 'minioadmin'})

  Application.aws_signer = Aws::S3::Presigner.new

  credentials = Aws::Credentials.new('minioadmin', 'minioadmin')

  Application.aws_client = Aws::S3::Client.new(
    endpoint: 'http://minio:9000',
    credentials: credentials,
    region: 'us-east-1',
    force_path_style: true)

  Tus::Server.opts[:storage] = Tus::Storage::S3.new(
      endpoint:          'http://minio:9000',
      access_key_id:     'minioadmin',
      secret_access_key: 'minioadmin',
      force_path_style:  true,
      prefix:            'uploads',
      bucket:            STORAGE_CONFIG[:storage][0][:bucket], # required
      region:            "us-east-1")

else
  Tus::Server.opts[:storage] = Tus::Storage::Filesystem.new(STORAGE_CONFIG[:storage][0][:path] )
end


