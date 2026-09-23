# frozen_string_literal: true

require "faraday"
require "json"
require "jwt"
require "singleton"

class TdxClient
  include Singleton

  BASE_URL = TICKET_CONFIG[:base_url]
  API_BASE_URL = BASE_URL.to_s.end_with?("/api") ? BASE_URL.to_s.chomp("/") : "#{BASE_URL.to_s.chomp("/")}/api"
  USERNAME = TICKET_CONFIG[:username]
  PASSWORD = TICKET_CONFIG[:password]
  APP_ID = TICKET_CONFIG[:app_id]
  FORM_ID = TICKET_CONFIG[:form_id]
  GROUP_ID = TICKET_CONFIG[:group_id]
  NOREPLY_REQUESTOR_UID = TICKET_CONFIG[:noreply_requestor_uid]
  TOKEN_REFRESH_BUFFER_SECONDS = 60
  AUTH_ENDPOINT = "#{API_BASE_URL}/auth".freeze
  TICKETS_ENDPOINT = "#{API_BASE_URL}/#{APP_ID}/tickets".freeze
  GLOBAL_TICKETS_ENDPOINT = "#{API_BASE_URL}/tickets".freeze

  private_constant :BASE_URL, :API_BASE_URL, :USERNAME, :PASSWORD, :APP_ID,
                   :TOKEN_REFRESH_BUFFER_SECONDS, :AUTH_ENDPOINT,
                   :TICKETS_ENDPOINT, :GLOBAL_TICKETS_ENDPOINT, :GROUP_ID

  # @return [Array<Hash>] configured assignees, normalized to {netid:, name:, email:, uid:}
  def self.assignees
    (TICKET_CONFIG[:assignees] || []).map do |entry|
      netid, attrs = entry.first
      attrs = (attrs || {}).stringify_keys
      { netid: netid.to_s, name: attrs["name"], email: attrs["email"], uid: attrs["UID"] }
    end
  end

  # @return [Hash] the first configured assignee, used when none has been selected
  def self.default_assignee
    assignees.first
  end

  # @return [String, nil] the persisted netid of the currently selected assignee
  def self.current_assignee_netid
    path = TICKET_CONFIG[:current_assignee_path]
    return nil unless path.present? && File.file?(path)

    netid = File.read(path).strip
    netid.presence
  end

  # @return [Hash, nil] the currently selected assignee, falling back to the default
  def self.current_assignee
    assignees.find { |assignee| assignee[:netid] == current_assignee_netid } || default_assignee
  end

  # @param config [Hash] expects "current_assignee_netid" identifying a configured assignee
  # @return [Boolean] whether the update was persisted
  def self.update_config(config)
    netid = config && config["current_assignee_netid"]
    return false if netid.blank?
    return false unless assignees.any? { |assignee| assignee[:netid] == netid }

    path = TICKET_CONFIG[:current_assignee_path]
    return false if path.blank?

    worked = false
    File.open(path, "w") do |file|
      bytes_written = file.write(netid)
      worked = bytes_written.positive?
    end
    worked
  end

  def initialize
    @token = nil
    @token_expires_at = nil
    @token_mutex = Mutex.new
  end

  def current_token
    return @token if valid_token?

    @token_mutex.synchronize do
      return @token if valid_token?

      authenticate!
    end
  end

  def create_ticket(title:, description:, assignee_netid: TdxClient.current_assignee[:netid])
    post_json(TICKETS_ENDPOINT, {
                Title: title,
                Description: description,
                RequestorUid: NOREPLY_REQUESTOR_UID,
                ResponsibleUID: assignee_netid,
                FormID: FORM_ID,
                ResponsibleGroupID: GROUP_ID
              }, "TeamDynamix ticket creation failed")
  end

  def find_ticket_by_id(ticket_id)
    response = authenticated_request do |token|
      connection.get("#{GLOBAL_TICKETS_ENDPOINT}/#{ticket_id}") do |request|
        request.headers["Authorization"] = "Bearer #{token}"
      end
    end

    return nil unless response
    return nil if response.status == 404
    return parse_response_body(response.body) if response.status.between?(200, 299)

    raise "TeamDynamix ticket lookup failed (#{response.status}): #{response.body}"
  end

  def find_ticket_by_title(title)
    tickets = post_json(TICKETS_ENDPOINT + "/search", { SearchText: title }, "TeamDynamix ticket search failed")
    return unless tickets.is_a?(Array)

    tickets.find { |ticket| ticket["Title"] == title || ticket["title"] == title }
  end

  def update_ticket(ticket_id:, title:, description:, assignee_netid: TdxClient.current_assignee[:netid])
    patch_json("#{TICKETS_ENDPOINT}/#{ticket_id}", [
                 { op: "replace", path: "/Title", value: title },
                 { op: "replace", path: "/Description", value: description },
                 { op: "replace", path: "/ResponsibleUID", value: assignee_netid }
               ], "TeamDynamix ticket update failed")
  end

  def comments(ticket_id: )
    response = authenticated_request do |token|
      connection.get("#{TICKETS_ENDPOINT}/#{ticket_id}/feed") do |request|
        request.headers["Authorization"] = "Bearer #{token}"
      end
    end

    return nil unless response
    return nil if response.status == 404
    return parse_response_body(response.body) if response.status.between?(200, 299)

    raise "TeamDynamix ticket comments lookup failed (#{response.status}): #{response.body}"
  end

  def add_comment(ticket_id:, comment:)
    post_json("#{TICKETS_ENDPOINT}/#{ticket_id}/feed", { Comments: comment }, "TeamDynamix add comment failed")
  end

  private

  def connection
    @connection ||= Faraday.new(url: API_BASE_URL) do |faraday|
      faraday.request :json
      faraday.response :json, content_type: /json/
      faraday.adapter Faraday.default_adapter
    end
  end

  def valid_token?
    return false if @token.blank? || @token_expires_at.blank?

    @token_expires_at.to_i > Time.current.to_i + TOKEN_REFRESH_BUFFER_SECONDS
  end

  def authenticate!
    response = connection.post(AUTH_ENDPOINT) do |request|
      request.headers["Content-Type"] = "application/json"
      request.body = {
        username: USERNAME,
        password: PASSWORD
      }.to_json
    end

    return log_authentication_failure("unexpected status #{response.status}: #{response.body}") unless response.status == 200

    @token = response.body.to_s.strip
    return log_authentication_failure("empty token") if @token.blank?

    payload, = JWT.decode(@token, nil, false)
    @token_expires_at = payload["exp"].to_i
    return log_authentication_failure("missing exp claim") if @token_expires_at.zero?

    @token
  rescue Faraday::Error, JWT::DecodeError => e
    log_authentication_failure("#{e.class}: #{e.message}")
  end

  def post_json(url, body, error_message)
    response = authenticated_request do |token|
      connection.post(url) do |request|
        request.headers["Content-Type"] = "application/json"
        request.headers["Authorization"] = "Bearer #{token}"
        request.body = body.to_json
      end
    end

    return nil unless response
    return parse_response_body(response.body) if response.status.between?(200, 299)

    raise "#{error_message} (#{response.status}): #{response.body}"
  end

  def patch_json(url, body, error_message)
    response = authenticated_request do |token|
      connection.patch(url) do |request|
        request.headers["Content-Type"] = "application/json-patch+json"
        request.headers["Authorization"] = "Bearer #{token}"
        request.body = body.to_json
      end
    end

    return nil unless response
    return parse_response_body(response.body) if response.status.between?(200, 299)

    raise "#{error_message} (#{response.status}): #{response.body}"
  end

  def authenticated_request
    token = current_token
    return nil if token.blank?

    response = yield(token)
    return response unless response.status == 401

    @token = nil
    @token_expires_at = nil
    token = current_token
    return nil if token.blank?

    yield(token)
  end

  def log_authentication_failure(message)
    @token = nil
    @token_expires_at = nil
    Rails.logger.error("TeamDynamix authentication failed: #{message}")
    nil
  end

  def parse_response_body(body)
    return body if body.is_a?(Hash) || body.is_a?(Array)
    return nil if body.blank?

    JSON.parse(body)
  rescue JSON::ParserError
    body
  end
end
