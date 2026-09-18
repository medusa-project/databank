# frozen_string_literal: true

require "faraday"
require "json"
require "jwt"
require "singleton"

class TdxClient
  include Singleton

  BASE_URL = IDB_CONFIG[:tdx][:base_url]
  API_BASE_URL = BASE_URL.to_s.end_with?("/api") ? BASE_URL.to_s.chomp("/") : "#{BASE_URL.to_s.chomp("/")}/api"
  USERNAME = IDB_CONFIG[:tdx][:username]
  PASSWORD = IDB_CONFIG[:tdx][:password]
  APP_ID = IDB_CONFIG[:tdx][:app_id]
  FORM_ID = IDB_CONFIG[:tdx][:form_id]
  GROUP_ID = IDB_CONFIG[:tdx][:group_id]
  NOREPLY_REQUESTOR_UID = IDB_CONFIG[:tdx][:noreply_requestor_uid]
  TOKEN_REFRESH_BUFFER_SECONDS = 60
  AUTH_ENDPOINT = "#{API_BASE_URL}/auth".freeze
  TICKETS_ENDPOINT = "#{API_BASE_URL}/#{APP_ID}/tickets".freeze
  GLOBAL_TICKETS_ENDPOINT = "#{API_BASE_URL}/tickets".freeze

  private_constant :BASE_URL, :API_BASE_URL, :USERNAME, :PASSWORD, :APP_ID,
                   :TOKEN_REFRESH_BUFFER_SECONDS, :AUTH_ENDPOINT,
                   :TICKETS_ENDPOINT, :GLOBAL_TICKETS_ENDPOINT, :GROUP_ID

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

  def create_ticket(title:, description:)
    post_json(TICKETS_ENDPOINT, {
                Title: title,
                Description: description,
                RequestorUid: NOREPLY_REQUESTOR_UID,
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

  def update_ticket(ticket_id:, title:, description:)
    patch_json("#{TICKETS_ENDPOINT}/#{ticket_id}", [
                 { op: "replace", path: "/Title", value: title },
                 { op: "replace", path: "/Description", value: description },
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
