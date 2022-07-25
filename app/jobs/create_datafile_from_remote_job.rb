require 'tempfile'
require 'open-uri'
require 'fileutils'
require 'net/http'
require 'aws-sdk-s3'

class CreateDatafileFromRemoteJob < ProgressJob::Base

  Thread.abort_on_exception=true

  FIVE_MB = 1024 * 1024 * 5

  def initialize(dataset_id, datafile, remote_url, filename, filesize)
    @remote_url = remote_url
    @dataset_id = dataset_id
    @datafile = datafile
    @filename = filename
    @filesize = filesize #string because it is used in display

    if filesize.to_f < 4000
      progress_max = 2
    else
      progress_max = (filesize.to_f / 4000).to_i + 1
    end

    super progress_max: progress_max
  end

  def perform

    more_segs_to_do = true
    upload_incomplete = true

    @datafile.binary_name = @filename
    @datafile.storage_root = StorageManager.instance.draft_root.name
    @datafile.storage_key = File.join(@datafile.web_id, @filename)
    @datafile.binary_size = @filesize
    @datafile.save!

    if IDB_CONFIG[:aws][:s3_mode]

      upload_key = @datafile.storage_key
      upload_bucket = StorageManager.instance.draft_root.bucket

      if StorageManager.instance.draft_root.prefix
        upload_key = "#{StorageManager.instance.draft_root.prefix}#{@datafile.storage_key}"
      end

      client = Application.aws_client

      if @filesize.to_f < FIVE_MB
        web_contents = open(@remote_url) {|f| f.read}
        StorageManager.instance.draft_root.copy_io_to(@datafile.storage_key, web_contents, nil, @filesize.to_f)
        upload_incomplete = false

      else

        parts = []

        seg_queue = Queue.new

        mutex = Mutex.new

        segs_complete = false
        segs_todo = 0
        segs_done = 0

        begin

          upload_id = aws_mulitpart_start(client, upload_bucket, upload_key)

          seg_producer = Thread.new do

            uri = URI.parse(@remote_url)

            Net::HTTP.start(uri.host, uri.port, :use_ssl => (uri.scheme == 'https')) {|http|
              http.request_get(uri.path) {|res|

                res.read_body {|seg|
                  mutex.synchronize {
                    segs_todo = segs_todo + 1
                  }
                  seg_queue << seg
                  update_progress
                }
              }
            }
            mutex.synchronize {
              segs_complete = true
            }

          end

          seg_consumer = Thread.new do

            part_number = 1

            partio = StringIO.new("", 'wb+')

            while seg = seg_queue.deq # wait for queue to be closed in controller thread

              partio << seg

              if partio.size > FIVE_MB

                partio.rewind

                mutex.synchronize {

                  etag = aws_upload_part(client, partio, upload_bucket, upload_key, part_number, upload_id)

                  parts_hash = {etag: etag, part_number: part_number}

                  parts.push(parts_hash)

                }

                part_number = part_number + 1

                partio.close if partio&.closed?

                partio = StringIO.new("", 'wb+')

              end

              mutex.synchronize {
                segs_done = segs_done + 1
              }

            end

            # upload last part, less than 5 MB
            mutex.synchronize {

              partio.rewind

              etag = aws_upload_part(client, partio, upload_bucket, upload_key, part_number, upload_id)

              parts_hash = {etag: etag, part_number: part_number}

              parts.push(parts_hash)

              partio.close if partio&.closed?

              aws_complete_upload(client, upload_bucket, upload_key, parts, upload_id)

              upload_incomplete = false
            }

          end

          controller = Thread.new do

            while more_segs_to_do
              sleep 0.9
              mutex.synchronize {
                if segs_complete && ( segs_done == segs_todo)
                  more_segs_to_do = false
                end
              }
            end

            seg_queue.close

          end

        rescue Exception => ex
          # ..|..
          #

          Rails.logger.warn("something went wrong during multipart upload")
          Rails.logger.warn(ex.class)
          Rails.logger.warn(ex.message)
          ex.backtrace.each do |line|
            Rails.logger.warn(line)
          end

          Application.aws_client.abort_multipart_upload({
                                                            bucket: upload_bucket,
                                                            key: upload_key,
                                                            upload_id: upload_id,
                                                        })
          raise ex

        end

      end

    else

      filepath = "#{StorageManager.instance.draft_root.path}/#{@datafile.storage_key}"

      dir_name = File.dirname(filepath)

      FileUtils.mkdir_p(dir_name) unless File.directory?(dir_name)

      File.open(filepath, 'wb+') do |outfile|
        uri = URI.parse(@remote_url)
        Net::HTTP.start(uri.host, uri.port, :use_ssl => (uri.scheme == 'https')) {|http|
          http.request_get(uri.path) {|res|

            res.read_body {|seg|
              outfile << seg
              update_progress
            }
          }
        }

      end

      upload_incomplete = false

    end

    while upload_incomplete
      sleep 1.3
    end

  end

  def aws_mulitpart_start(client, upload_bucket, upload_key)
    start_response = client.create_multipart_upload({
                                                        bucket: upload_bucket,
                                                        key: upload_key,
                                                    })

    start_response.upload_id

  end

  def aws_upload_part(client, partio, upload_bucket, upload_key, part_number, upload_id)

    part_response = client.upload_part({
                                           body: partio,
                                           bucket: upload_bucket,
                                           key: upload_key,
                                           part_number: part_number,
                                           upload_id: upload_id,
                                       })

    part_response.etag


  end

  def aws_complete_upload(client, upload_bucket, upload_key, parts, upload_id)

    response = client.complete_multipart_upload({
                                                    bucket: upload_bucket,
                                                    key: upload_key,
                                                    multipart_upload: {parts: parts, },
                                                    upload_id: upload_id,
                                                })
  end

end

