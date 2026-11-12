# frozen_string_literal: true

require "signet/oauth_2/client"
require "net/http"

module GoogleDrive
  class Client
    SCOPE = "https://www.googleapis.com/auth/drive.file"
    FILE_FIELDS = "id,name,size,mimeType,md5Checksum,version,modifiedTime,driveId,trashed,capabilities(canDownload)"
    MAX_BYTES = 10_000_000_000
    CHUNK_BYTES = 8 * 1024 * 1024

    def self.settings
      IDB_CONFIG.fetch(:google, {})
    end

    def self.ensure_configured!
      return if [:client_id, :client_secret, :api_key, :project_number].all? {|key| settings[key].present? }

      raise Error, "Google Drive import is not configured. Contact the Research Data Service."
    end

    def self.oauth_client(**options)
      Signet::OAuth2::Client.new({
        authorization_uri:    "https://accounts.google.com/o/oauth2/v2/auth",
        token_credential_uri: "https://oauth2.googleapis.com/token",
        client_id:            settings[:client_id],
        client_secret:        settings[:client_secret],
        scope:                SCOPE
      }.merge(options))
    end

    def self.exchange_code(code:, redirect_uri:, verifier:)
      client = oauth_client(code: code, redirect_uri: redirect_uri)
      token_request(client, additional_parameters: {code_verifier: verifier})
    end

    def self.token_request(client, **options)
      transport = Faraday.new do |builder|
        builder.options.open_timeout = 10
        builder.options.timeout = 30
        builder.adapter Faraday.default_adapter
      end
      client.fetch_access_token!({connection: transport}.merge(options))
      client
    rescue Signet::AuthorizationError, Signet::ParseError, Signet::UnexpectedStatusError
      raise Error, "Google authorization expired or was denied. Authorize Google Drive again."
    rescue Signet::RemoteServerError, Faraday::ConnectionFailed, Faraday::TimeoutError
      raise RetryableError, "Google authorization is temporarily unavailable. Please try again."
    end

    def initialize(connection)
      @connection = connection
    end

    def metadata(file_id)
      raise Error, "Select a valid Google Drive file." unless file_id.to_s.match?(/\A[a-zA-Z0-9_-]{1,200}\z/)

      uri = URI("https://www.googleapis.com/drive/v3/files/#{file_id}")
      uri.query = URI.encode_www_form(fields: FILE_FIELDS)
      response = request(uri)
      JSON.parse(response.body)
    rescue JSON::ParserError
      raise RetryableError, "Google Drive returned an invalid response. Please try again."
    end

    def self.validate_metadata!(metadata)
      if metadata["trashed"] || metadata["capabilities"]&.fetch("canDownload", false) != true
        raise Error, "This file cannot be downloaded. Check its Google Drive permissions."
      end
      if metadata["driveId"].present? || metadata["mimeType"].to_s.start_with?("application/vnd.google-apps.")
        raise Error,
              "Choose an ordinary file from My Drive or shared with you. Google documents, folders, shortcuts, and Shared Drives are not supported."
      end

      name = metadata["name"]
      if !name.is_a?(String) || name.blank? || name.bytesize > 255 || name.match?(%r{[/\\\x00-\x1f\x7f]}) || [".",
                                                                                                              ".."].include?(name)
        raise Error, "Rename this file in Google Drive before importing it."
      end
      unless metadata["size"].to_s.match?(/\A\d+\z/) && metadata["size"].to_i.between?(1, MAX_BYTES)
        raise Error, "Choose a nonempty file no larger than 10 GB."
      end
      raise Error, "Google Drive did not return a file version." if metadata["version"].blank?

      metadata
    end

    def chunk(metadata, offset)
      last_byte = [offset + CHUNK_BYTES, metadata.fetch("size").to_i].min - 1
      uri = URI("https://www.googleapis.com/drive/v3/files/#{metadata.fetch('id')}?alt=media")
      expected_range = "bytes #{offset}-#{last_byte}/#{metadata.fetch('size')}"
      response = request(uri, "Range" => "bytes=#{offset}-#{last_byte}") do |res|
        unless res.code == "206" && res["Content-Range"] == expected_range
          raise Error, "Google Drive did not return the requested file range. The import was stopped."
        end

        body = "".b
        res.read_body do |segment|
          if body.bytesize + segment.bytesize > last_byte - offset + 1
            raise Error,
                  "Google Drive returned more data than expected."
          end

          body << segment.b
        end
        body
      end
      unless response.bytesize == last_byte - offset + 1
        raise RetryableError,
              "Google Drive returned an incomplete file range."
      end

      response
    end

    private

    def request(uri, headers={}, &block)
      attempts = 0
      refreshed = false
      begin
        attempts += 1
        result = nil
        Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 60) do |http|
          request = Net::HTTP::Get.new(uri)
          request["Authorization"] = "Bearer #{@connection.access_token}"
          request["Accept-Encoding"] = "identity"
          headers.each {|key, value| request[key] = value }
          http.request(request) do |response|
            if response.code == "401" && !refreshed
              @connection.access_token(force_refresh: true)
              refreshed = true
              raise RetryableError, "Google authorization was refreshed."
            end
            check_response!(response)
            result = block ? block.call(response) : response.tap(&:read_body)
          end
        end
        result
      rescue RetryableError, Net::OpenTimeout, Net::ReadTimeout, IOError, SocketError,
             Errno::ECONNRESET, Errno::ECONNREFUSED, Errno::ETIMEDOUT
        if attempts < 3
          sleep(2**(attempts - 1))
          retry
        end
        raise RetryableError, "Google Drive could not complete the request. The import will retry."
      end
    end

    def check_response!(response)
      code = response.code.to_i
      return if code.between?(200, 299)
      raise RetryableError, "Google Drive is temporarily unavailable." if code == 429 || code >= 500

      if code == 403
        details = JSON.parse(response.body)
        reasons = details.dig("error", "errors").to_a.map {|error| error["reason"] }
        if (reasons & ["rateLimitExceeded", "userRateLimitExceeded", "downloadQuotaExceeded"]).any?
          raise RetryableError, "Google Drive download quota is temporarily exceeded."
        end
      end
      raise Error, "Google Drive denied access to this file (HTTP #{code}). Check permissions and authorize again."
    rescue JSON::ParserError
      raise Error, "Google Drive denied access to this file (HTTP #{code})."
    end
  end
end
