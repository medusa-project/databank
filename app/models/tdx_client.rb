# frozen_string_literal: true

require "faraday"
require "json"
require "jwt"
require "singleton"

class TdxClient
  include Singleton

  BASE_URL = IDB_CONFIG[:tdx][:base_url]
  USERNAME = IDB_CONFIG[:tdx][:username]
  PASSWORD = IDB_CONFIG[:tdx][:password]
  APP_ID = IDB_CONFIG[:tdx][:app_id]
  FORM_ID = IDB_CONFIG[:tdx][:form_id]
  NOREPLY_REQUESTOR_UID = IDB_CONFIG[:tdx][:noreply_requestor_uid]
  TOKEN_REFRESH_BUFFER_SECONDS = 60
  AUTH_ENDPOINT = "#{BASE_URL}/auth".freeze
  TICKETS_ENDPOINT = "#{BASE_URL}/#{APP_ID}/tickets".freeze

  private_constant :BASE_URL, :USERNAME, :PASSWORD, :APP_ID, :FORM_ID,
                   :NOREPLY_REQUESTOR_UID, :TOKEN_REFRESH_BUFFER_SECONDS,
                   :AUTH_ENDPOINT, :TICKETS_ENDPOINT

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

  def create_ticket(title:, description:, requestor_uid: NOREPLY_REQUESTOR_UID, form_id: FORM_ID)
    response = connection.post(TICKETS_ENDPOINT) do |request|
      request.headers["Content-Type"] = "application/json"
      request.headers["Authorization"] = "Bearer #{current_token}"
      request.body = {
        title: title,
        description: description,
        requestorUid: requestor_uid,
        formId: form_id
      }.to_json
    end

    if response.status == 401
      @token = nil
      @token_expires_at = nil
      response = connection.post(TICKETS_ENDPOINT) do |request|
        request.headers["Content-Type"] = "application/json"
        request.headers["Authorization"] = "Bearer #{current_token}"
        request.body = {
          title: title,
          description: description,
          requestorUid: requestor_uid,
          formId: form_id
        }.to_json
      end
    end

    return JSON.parse(response.body) if response.status.between?(200, 299)

    raise "TeamDynamix ticket creation failed (#{response.status}): #{response.body}"
  rescue JSON::ParserError
    response.body
  end

  private

  def connection
    @connection ||= Faraday.new(url: BASE_URL) do |faraday|
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

    raise "TeamDynamix authentication failed (#{response.status}): #{response.body}" unless response.status == 200

    @token = response.body.to_s.strip
    raise "TeamDynamix authentication failed: empty token" if @token.blank?

    payload, = JWT.decode(@token, nil, false)
    @token_expires_at = payload["exp"].to_i
    raise "TeamDynamix authentication failed: missing exp claim" if @token_expires_at.zero?

    @token
  end
end
