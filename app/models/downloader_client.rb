# frozen_string_literal: true

##
# DownloaderClient model
# @note: This model is used to download files from Medusa

require "json"
require "curb"

class DownloaderClient
  include ActiveModel::Conversion
  include ActiveModel::Naming
  # all methods are class methods
  class << self
    ##
    # datafiles_download_hash
    # ----------------------
    # @param dataset [Dataset] The dataset the files belong to
    # @param web_ids [Array] The web_ids of the files to download
    # @param zip_name [String] The name of the zip file to create
    def datafiles_download_hash(dataset:, web_ids:, zip_name:)
      begin
        targets_arr = targets_arr(dataset: dataset, web_ids: web_ids)
        return {"status": "error", "error": "internal error no valid files found"} unless targets_arr.count.positive?
      rescue StandardError => e
        Rails.logger.warn "error in datafiles_download_hash: #{e}"
        return {"status": "error", "error": "internal error file path not found"}
      end

      medusa_request_json = {"root": "idb", "zip_name": zip_name.to_s, "targets": targets_arr}.to_json
      download_hash = request_download_hash(medusa_request_json: medusa_request_json)
      download_hash[:total_size] = total_size(targets_arr: targets_arr) if download_hash[:status] == "ok"
      download_hash
    end

    private

    ##
    # targets_arr
    # -----------
    # @param dataset [Dataset] The dataset the files belong to
    # @param web_ids [Array] The web_ids of the files to download
    # @return [Array] The array of files to download
    def targets_arr(dataset:, web_ids:)
      targets_arr = []
      web_ids.each do |web_id|
        df = dataset.datafiles.find_by(web_id: web_id)
        targets_arr.push({"type": "file", "path": df.storage_key.to_s, "size": df.bytestream_size})
      end
      targets_arr.push({"type": "literal", "name": "dataset_info.txt", "content": dataset.record_text})
      targets_arr
    end

    ##
    # request_download_hash
    # ---------------------
    # @param medusa_request_json [String] The JSON string to send to the downloader
    # @return [Hash] The response hash from the downloader
    # @note: This method sends a request to the downloader to download the files
    def request_download_hash(medusa_request_json:)
      user = IDB_CONFIG["downloader"]["user"]
      password = IDB_CONFIG["downloader"]["password"]
      client = Curl::Easy.new((IDB_CONFIG["downloader"]["endpoint"]).to_s)
      client.http_auth_types = :digest
      client.ssl_verify_peer = true
      client.username = user
      client.password = password
      client.post_body = medusa_request_json
      client.post
      client.headers = {"Content-Type": "application/json"}
      client.perform
      response_hash = JSON.parse(client.body_str)
      return {"status": "error", "error": client.body_str} unless response_hash.has_key?("download_url")

      {"status": "ok", "download_url": response_hash["download_url"], "status_url": response_hash["status_url"]}
    rescue StandardError => e
      Rails.logger.warn "error in request_download_hash: #{e}"
      {"status": "error", "error": "internal error downloading files"}
    end

    ##
    # total_size
    # ----------
    # @param targets_arr [Array] The array of files to download
    # @return [Integer] The total size of the files to download
    def total_size(targets_arr:)
      total_size = 0
      targets_arr.each do |target|
        total_size += target["size"]
      end
      total_size
    end
  end
end
