# frozen_string_literal: true

require "net/http"

class BoxStorage::Client
  MAX_BYTES = CloudImports::MAX_BYTES
  CHUNK_BYTES = CloudImports::CHUNK_BYTES
  FILE_FIELDS = "id,type,name,size,sha1,file_version,permissions,is_download_available,item_status"

  def self.settings
    IDB_CONFIG.fetch(:box, {})
  end

  def self.ensure_configured!
    return if [:client_id, :client_secret].all? {|key| settings[key].present? }

    raise BoxStorage::Error, "Box import is not configured. Contact the Research Data Service."
  end

  def self.token_request(parameters)
    uri = URI("https://api.box.com/oauth2/token")
    request = Net::HTTP::Post.new(uri)
    request.set_form_data(parameters.merge(client_id: settings[:client_id], client_secret: settings[:client_secret]))
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) do |http|
      http.request(request)
    end
    if response.code.to_i == 429 || response.code.to_i >= 500
      raise BoxStorage::RetryableError, "Box authorization is temporarily unavailable."
    end
    unless response.code == "200"
      raise BoxStorage::Error, "Box authorization expired or was denied. Authorize Box again."
    end

    JSON.parse(response.body)
  rescue JSON::ParserError
    raise BoxStorage::RetryableError, "Box returned an invalid authorization response."
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, IOError, Errno::ECONNRESET, Errno::ECONNREFUSED
    raise BoxStorage::RetryableError, "Box authorization is temporarily unavailable."
  end

  def initialize(connection)
    @connection = connection
  end

  def picker_token
    self.class.token_request(
      grant_type: "urn:ietf:params:oauth:grant-type:token-exchange",
      subject_token: @connection.access_token,
      subject_token_type: "urn:ietf:params:oauth:token-type:access_token",
      scope: "base_picker"
    ).fetch("access_token")
  end

  def metadata(file_id)
    validate_id!(file_id)
    uri = URI("https://api.box.com/2.0/files/#{file_id}?#{URI.encode_www_form(fields: FILE_FIELDS)}")
    request(uri, authenticated: true) do |response|
      raw = JSON.parse(response.body)
      {
        "id" => raw["id"], "name" => raw["name"], "size" => raw["size"].to_s,
        "sha1" => raw["sha1"], "version" => raw.dig("file_version", "id"),
        "type" => raw["type"], "canDownload" => raw.dig("permissions", "can_download"),
        "available" => raw["is_download_available"], "item_status" => raw["item_status"],
        "mimeType" => Marcel::MimeType.for(name: raw["name"])
      }
    end
  rescue JSON::ParserError
    raise BoxStorage::RetryableError, "Box returned invalid file information."
  end

  def self.validate_metadata!(metadata)
    unless metadata["type"] == "file"
      raise BoxStorage::Error, "Choose a downloadable file in Box. Folders, links, and Box Notes are not supported."
    end
    unless metadata["item_status"] == "active"
      raise BoxStorage::Error, "This file is not active in Box. Choose a file that has not been deleted or trashed."
    end
    # Box can omit permissions; the authenticated content endpoint still enforces download access.
    unless metadata["canDownload"].nil? || metadata["canDownload"] == true
      raise BoxStorage::Error, "Box does not allow your account to download this file. Check its permissions or choose another file."
    end
    if metadata["available"] == false
      raise BoxStorage::Error, "Box reports that this file's content is not available for download. Choose another file or try again later."
    end
    name = metadata["name"]
    unless name.is_a?(String) && name.present? && name.bytesize <= 255 &&
           !name.match?(%r{[/\\\x00-\x1f\x7f]}) && ![".", ".."].include?(name) &&
           !name.downcase.end_with?(".boxnote")
      raise BoxStorage::Error, "Choose an ordinary file with a valid filename in Box."
    end
    unless metadata["size"].to_s.match?(/\A\d+\z/) && metadata["size"].to_i.between?(1, MAX_BYTES)
      raise BoxStorage::Error, "Choose a nonempty file no larger than 50 GB."
    end
    unless metadata["version"].present? && metadata["sha1"].to_s.match?(/\A[0-9a-f]{40}\z/i)
      raise BoxStorage::Error, "Box did not return a file version and checksum. Select another file."
    end

    metadata
  rescue BoxStorage::Error
    Rails.logger.warn("Box import metadata rejected: " \
                      "#{metadata.slice('type', 'canDownload', 'available', 'item_status').to_json}")
    raise
  end

  def chunk(metadata, offset)
    validate_id!(metadata.fetch("id"))
    last_byte = [offset + CHUNK_BYTES, metadata.fetch("size").to_i].min - 1
    uri = URI("https://api.box.com/2.0/files/#{metadata.fetch('id')}/content")
    uri.query = URI.encode_www_form(version: metadata.fetch("version"))
    headers = {"Range" => "bytes=#{offset}-#{last_byte}"}
    request(uri, authenticated: true, headers: headers, redirects: 5) do |response|
      expected = "bytes #{offset}-#{last_byte}/#{metadata.fetch('size')}"
      unless response.code == "206" && response["Content-Range"] == expected
        raise BoxStorage::Error, "Box did not return the requested file range. The import was stopped."
      end
      body = "".b
      response.read_body do |segment|
        if body.bytesize + segment.bytesize > last_byte - offset + 1
          raise BoxStorage::Error, "Box returned more data than expected."
        end
        body << segment.b
      end
      unless body.bytesize == last_byte - offset + 1
        raise BoxStorage::RetryableError, "Box returned an incomplete file range."
      end
      body
    end
  end

  private

  def validate_id!(id)
    raise BoxStorage::Error, "Select a valid Box file." unless id.to_s.match?(/\A\d{1,100}\z/)
  end

  def request(uri, authenticated:, headers: {}, redirects: 0, refreshed: false, &block)
    result = nil
    Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 60) do |http|
      get = Net::HTTP::Get.new(uri)
      get["Authorization"] = "Bearer #{@connection.access_token}" if authenticated
      get["Accept-Encoding"] = "identity"
      headers.each {|key, value| get[key] = value }
      http.request(get) do |response|
        code = response.code.to_i
        if code == 401 && authenticated && !refreshed
          @connection.access_token(force_refresh: true)
          result = request(uri, authenticated: true, headers: headers, redirects: redirects, refreshed: true, &block)
        elsif [301, 302, 303, 307, 308].include?(code)
          location = URI.join(uri, response["Location"].to_s)
          validate_redirect!(location, redirects)
          result = request(location, authenticated: false, headers: headers, redirects: redirects - 1, &block)
        else
          check_response!(response)
          result = block.call(response)
        end
      end
    end
    result
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, IOError, Errno::ECONNRESET, Errno::ECONNREFUSED
    raise BoxStorage::RetryableError, "Box could not complete the request. The import will retry."
  end

  def validate_redirect!(uri, remaining)
    unless remaining.positive? && uri.scheme == "https" && uri.port == 443 && uri.userinfo.nil? &&
           (uri.host == "dl.boxcloud.com" || uri.host&.end_with?(".boxcloud.com"))
      raise BoxStorage::Error, "Box returned an unexpected download location."
    end
  end

  def check_response!(response)
    code = response.code.to_i
    return if code.between?(200, 299) && code != 202
    if code == 202 || code == 429 || code >= 500
      raise BoxStorage::RetryableError, "Box is preparing the file or is temporarily unavailable. The import will retry."
    end

    raise BoxStorage::Error, "Box denied access to this file (HTTP #{code}). Check permissions and authorize again."
  end
end
