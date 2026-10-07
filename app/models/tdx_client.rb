# frozen_string_literal: true

require "faraday"
require "json"
require "jwt"
require "singleton"
require "fileutils"

class TdxClient
  include Singleton

  BASE_URL = TICKET_CONFIG[:base_url]
  API_BASE_URL = BASE_URL.to_s.end_with?("/api") ? BASE_URL.to_s.chomp("/") : "#{BASE_URL.to_s.chomp("/")}/api"
  USERNAME = TICKET_CONFIG[:username]
  PASSWORD = TICKET_CONFIG[:password]
  APP_ID = TICKET_CONFIG[:app_id]
  FORM_ID = TICKET_CONFIG[:form_id]
  CONSULT_FORM_ID = TICKET_CONFIG[:consult_form_id]
  CONSULT_ATTRIBUTE_ID = TICKET_CONFIG[:consult_attribute_id]
  GROUP_ID = TICKET_CONFIG[:group_id]
  NOREPLY_REQUESTOR_UID = TICKET_CONFIG[:noreply_requestor_uid]
  TOKEN_REFRESH_BUFFER_SECONDS = 60
  AUTH_ENDPOINT = "#{API_BASE_URL}/auth".freeze
  PEOPLE_ENDPOINT = "#{API_BASE_URL}/people".freeze
  TICKETS_ENDPOINT = "#{API_BASE_URL}/#{APP_ID}/tickets".freeze
  GLOBAL_TICKETS_ENDPOINT = "#{API_BASE_URL}/tickets".freeze

  private_constant :BASE_URL, :API_BASE_URL, :USERNAME, :PASSWORD, :APP_ID,
                   :TOKEN_REFRESH_BUFFER_SECONDS, :AUTH_ENDPOINT, :PEOPLE_ENDPOINT,
                   :TICKETS_ENDPOINT, :GLOBAL_TICKETS_ENDPOINT, :GROUP_ID

  # @return [Array<Hash>] configured assignees, normalized to {netid:, name:, email:, uid:}
  def self.assignees
    @assignees ||= (TICKET_CONFIG[:assignees] || []).map do |entry|
      netid, attrs = entry.first
      attrs = (attrs || {}).stringify_keys
      { netid: netid.to_s, name: attrs["name"], email: attrs["email"], uid: attrs["UID"] }
    end
  end

  def assignee_uid_from(netid:)
    assignee = self.class.assignees.find { |a| a[:netid] == netid.to_s }
    assignee ? assignee[:uid] : nil
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

  def assign_ticket(ticket_id:, assignee_uid: TdxClient.current_assignee[:uid])
    update_ticket(ticket_id: ticket_id, error_message: "Assigning ticket to #{assignee_uid}",
                  assignee_uid: assignee_uid, notify_new_responsible: true)
  end

  # @param config [Hash] expects "current_assignee_netid" identifying a configured assignee
  # @return [Boolean] whether the update was persisted
  def self.update_config(config)
    netid = config && config["current_assignee_netid"]
    return false if netid.blank?
    return false unless assignees.any? { |assignee| assignee[:netid] == netid }

    path = TICKET_CONFIG[:current_assignee_path]
    return false if path.blank?

    FileUtils.mkdir_p(File.dirname(path))
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

  # returns the ID of the created ticket if successful, or nil if response is unexpected
  # could raise an exception if ticket creation fails
  def create_ticket(title:, description:, requestor_uid: nil, form_id: FORM_ID, attributes: nil, assignee_uid: TdxClient.current_assignee[:uid])
    requestor_uid ||= NOREPLY_REQUESTOR_UID
    if form_id == CONSULT_FORM_ID && !attributes.is_a?(Array)
      raise ArgumentError, "Consult tickets require attributes to be an array"
    end

    payload = {
      Title: title,
      Description: description,
      RequestorUid: requestor_uid,
      ResponsibleUID: assignee_uid,
      FormID: form_id,
      ResponsibleGroupID: GROUP_ID
    }
    payload[:Attributes] = attributes if form_id == CONSULT_FORM_ID

    response = post_json(url: TICKETS_ENDPOINT, body: payload, error_message: "TeamDynamix ticket creation failed")
    response["ID"] if response.is_a?(Hash)
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
    tickets = post_json(url: TICKETS_ENDPOINT + "/search", body: { SearchText: title },
                        error_message: "TeamDynamix ticket search failed")
    return unless tickets.is_a?(Array)

    tickets.find { |ticket| ticket["Title"] == title || ticket["title"] == title }
  end

  def update_ticket(ticket_id:, title: nil, description: nil, assignee_uid: nil,
                    notify_new_responsible: false, error_message: "TeamDynamix ticket update failed")
    body = []
    body << { op: "replace", path: "/Title", value: title } unless title.nil?
    body << { op: "replace", path: "/Description", value: description } unless description.nil?
    body << { op: "replace", path: "/ResponsibleUID", value: assignee_uid } unless assignee_uid.nil?
    return nil if body.empty?

    patch_json(
      url: "#{TICKETS_ENDPOINT}/#{ticket_id}",
      body: body,
      error_message: error_message,
      notify_new_responsible: notify_new_responsible
    )
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

  def add_comment(ticket_id:, comment:, notify: [])
    raise "Ticket ID is required to add a comment" if ticket_id.blank?

    raise "Ticket not found" if find_ticket_by_id(ticket_id).nil?

    # require notify to be an array, empty or containing only strings
    notify = [notify] if notify.is_a?(String)
    # if notify is not a string or nil or array of strings, set it to an empty array
    notify = [] unless notify.is_a?(Array) && notify.all? { |n| n.is_a?(String) }

    post_json(url: "#{TICKETS_ENDPOINT}/#{ticket_id}/feed", body: { Comments: comment, Notify: notify },
              error_message: "TeamDynamix add comment failed")
    ticket_id
  end

  def contacts(ticket_id:)
    response = authenticated_request do |token|
      connection.get("#{TICKETS_ENDPOINT}/#{ticket_id}/contacts") do |request|
        request.headers["Authorization"] = "Bearer #{token}"
      end
    end

    return nil unless response
    return nil if response.status == 404
    return parse_response_body(response.body) if response.status.between?(200, 299)

    raise "TeamDynamix ticket contacts lookup failed (#{response.status}): #{response.body}"
  end

  def add_contact(ticket_id:, person_uid:)
    contact_request(ticket_id: ticket_id, contact_uid: person_uid, action: "add")
  end

  def remove_contact(ticket_id:, person_uid:)
    contact_request(ticket_id: ticket_id, contact_uid: person_uid, action: "remove")
  end

  def person_uid_from_email(email:)
    response = authenticated_request do |token|
      connection.get("#{PEOPLE_ENDPOINT}/email/#{ERB::Util.url_encode(email)}") do |request|
        request.headers["Authorization"] = "Bearer #{token}"
      end
    end

    return nil unless response&.status&.between?(200, 299)

    person = parse_response_body(response.body)
    person["UID"] if person.is_a?(Hash)
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

  def post_json(url:, body:, error_message:)
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

  def patch_json(url:, body:, error_message:, notify_new_responsible: false)
    response = authenticated_request do |token|
      connection.patch(url) do |request|
        request.params["notifyNewResponsible"] = true if notify_new_responsible
        request.headers["Content-Type"] = "application/json-patch+json"
        request.headers["Authorization"] = "Bearer #{token}"
        request.body = body.to_json
      end
    end

    return nil unless response
    return parse_response_body(response.body) if response.status.between?(200, 299)

    raise "#{error_message} (#{response.status}): #{response.body}"
  end

  def contact_request(ticket_id:, contact_uid:, action:)
    response = authenticated_request do |token|
      connection.public_send(action == "add" ? :post : :delete,
                             "#{TICKETS_ENDPOINT}/#{ticket_id}/contacts/#{ERB::Util.url_encode(contact_uid.to_s)}") do |request|
        request.headers["Content-Type"] = "application/json"
        request.headers["Authorization"] = "Bearer #{token}"
      end
    end

    return nil unless response
    return parse_response_body(response.body) if response.status.between?(200, 299)

    raise "TeamDynamix #{action} contact failed (#{response.status}): #{response.body}"
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
