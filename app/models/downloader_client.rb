# frozen_string_literal: true

require "json"
require "curb"

class DownloaderClient
  include ActiveModel::Conversion
  include ActiveModel::Naming

  # precondition: all targets are in Medusa

  def self.datafiles_download_hash(dataset, web_ids, zipname)
    download_hash = {}
    total_size = 0

    # web_ids is expected to be an array

    num_files = 0
    if web_ids.respond_to?(:count)
      num_files = web_ids.count
    else
      download_hash["status"] = "error"
      download_hash["error"] = "internal error invalid file identifiers"
      return download_hash
    end
    if num_files.zero?
      download_hash["status"] = "error"
      download_hash["error"] = "no valid file identifiers found"
      return download_hash
    end

    targets_arr = []

    web_ids.each do |web_id|
      df = Datafile.find_by(web_id: web_id)

      next unless df

      if !df.storage_root || df.storage_root != "medusa" || !df.storage_key || df.storage_key == ""
        # should not get here because of precondition
        Rails.logger.warn "invalid storage_root / storage_key for datafile #{df.to_yaml}"
        download_hash["status"] = "error"
        download_hash["error"] = "internal error file path not found"
        return download_hash
      end
      total_size += df.bytestream_size
      target_hash = {}
      target_hash["type"] = "file"
      target_hash["path"] = df.storage_key.to_s
      targets_arr.push(target_hash)
    end

    recordfile_hash = {}
    recordfile_hash["type"] = "literal"
    recordfile_hash["name"] = "dataset_info.txt"
    recordfile_hash["content"] = dataset.recordtext
    targets_arr.push(recordfile_hash)

    total_size += dataset.recordtext.bytesize

    if targets_arr.count.zero?
      download_hash["status"] = "error"
      download_hash["error"] = "internal error: no valid files found"
      return download_hash
    end
    medusa_request_hash = {}
    medusa_request_hash["root"] = "idb"
    medusa_request_hash["zip_name"] = zipname.to_s
    medusa_request_hash["targets"] = targets_arr
    medusa_request_json = medusa_request_hash.to_json
    client_url = (IDB_CONFIG["downloader"]["endpoint"]).to_s
    begin
      user = IDB_CONFIG["downloader"]["user"]
      password = IDB_CONFIG["downloader"]["password"]
      client = Curl::Easy.new(client_url)
      client.http_auth_types = :digest
      client.ssl_verify_peer = true
      client.username = user
      client.password = password
      client.post_body = medusa_request_json
      client.post
      client.headers = {"Content-Type": "application/json"}
      client.perform
      # DEBUG LOGGING
      Rails.logger.warn client.to_yaml
      Rails.logger.warn client.body_str
      response_hash = JSON.parse(client.body_str)
      if response_hash.has_key?("download_url")
        # Rails.logger.warn "inside downloader client: #{response_hash["download_url"]}"
        download_hash["status"] = "ok"
        download_hash["download_url"] = response_hash["download_url"]
        download_hash["status_url"] = response_hash["status_url"]
        download_hash["total_size"] = total_size
      else
        Rails.logger.warn "*** invalid download response: #{client.body_str} to request: #{medusa_request_json}"
        download_hash["status"] = "error"
        download_hash["error"] = "invalid response from downloader service "
      end
      return download_hash
    rescue StandardError => e
      Rails.logger.warn "error interacting with medusa-downloader #{e}"
      download_hash["status"] = "error"
      download_hash["error"] = "invalid response from downloader service "
      return download_hash
    end

    # should not get here
    nil
  end
end
