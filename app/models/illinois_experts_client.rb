# frozen_string_literal: true

##
# Represents a client used to interact with the Illinois Experts API
# Used to generate a document consumed by the Illinois Experts System
# Gets information about a person from the Illinois Experts System

require "nokogiri"
require "open-uri"
require "cgi"
require "json"
require "net/http"
require "openssl"
require "benchmark"

class IllinoisExpertsClient
  include ActiveModel::Conversion
  include ActiveModel::Naming

  ENDPOINT = IDB_CONFIG[:illinois_experts][:endpoint]
  KEY = IDB_CONFIG[:illinois_experts][:key]
  INTERNAL_EMAIL_DOMAINS = %w[uiuc.edu illinois.edu uillinois.edu].freeze
  ENDPOINT_OVERRIDE_ENV = "ILLINOIS_EXPERTS_ENDPOINT_OVERRIDE"
  KEY_OVERRIDE_ENV = "ILLINOIS_EXPERTS_KEY_OVERRIDE"
  OPEN_TIMEOUT_SECONDS = 10
  READ_TIMEOUT_SECONDS = 30
  REQUEST_RETRIES = 3
  private_constant :ENDPOINT
  private_constant :KEY
  private_constant :INTERNAL_EMAIL_DOMAINS
  private_constant :ENDPOINT_OVERRIDE_ENV
  private_constant :KEY_OVERRIDE_ENV
  private_constant :OPEN_TIMEOUT_SECONDS
  private_constant :READ_TIMEOUT_SECONDS
  private_constant :REQUEST_RETRIES

  # Runs a one-off confirmation over a list of emails and returns summary stats.
  #
  # @param emails [Array<String>] emails to check
  # @param dry_run [Boolean] when true, only returns planning information
  # @return [Hash]
  def self.confirm_persons_lookup(emails:, dry_run: false)
    normalized_emails = Array(emails).map { |email| email.to_s.strip.downcase }.reject(&:blank?).uniq
    internal_emails, non_internal_emails = normalized_emails.partition { |email| internal_email?(email) }

    report = {
      endpoint_host: safe_endpoint_host,
      key_present: api_key.present?,
      requested_count: normalized_emails.length,
      internal_requested_count: internal_emails.length,
      skipped_non_internal_count: non_internal_emails.length,
      dry_run: dry_run,
      found_count: 0,
      missing_count: internal_emails.length,
      with_org_uuid_count: 0,
      with_start_date_count: 0,
      elapsed_seconds: 0.0
    }

    return report if dry_run

    found = 0
    with_org_uuid = 0
    with_start_date = 0

    elapsed = Benchmark.realtime do
      internal_emails.each do |email|
        doc = person_xml_doc(email)
        next if doc.nil?

        found += 1
        with_org_uuid += 1 if doc.at_xpath("//organisationalUnit/@uuid")
        with_start_date += 1 if doc.at_xpath("//period/startDate")
      end
    end

    report[:found_count] = found
    report[:missing_count] = internal_emails.length - found
    report[:with_org_uuid_count] = with_org_uuid
    report[:with_start_date_count] = with_start_date
    report[:elapsed_seconds] = elapsed.round(3)
    report
  end

  # Temporarily override only Illinois Experts endpoint/key for the duration
  # of the provided block.
  def self.with_overrides(endpoint: nil, key: nil)
    previous_endpoint = ENV[ENDPOINT_OVERRIDE_ENV]
    previous_key = ENV[KEY_OVERRIDE_ENV]

    ENV[ENDPOINT_OVERRIDE_ENV] = endpoint if endpoint.present?
    ENV[KEY_OVERRIDE_ENV] = key if key.present?

    yield
  ensure
    ENV[ENDPOINT_OVERRIDE_ENV] = previous_endpoint
    ENV[KEY_OVERRIDE_ENV] = previous_key
  end

  def self.endpoint
    ENV[ENDPOINT_OVERRIDE_ENV].presence || ENDPOINT
  end
  private_class_method :endpoint

  def self.api_key
    ENV[KEY_OVERRIDE_ENV].presence || KEY
  end
  private_class_method :api_key

  def self.safe_endpoint_host
    URI.parse(endpoint).host
  rescue URI::InvalidURIError
    nil
  end
  private_class_method :safe_endpoint_host

  def self.internal_email?(email)
    domain = email.to_s.split("@", 2).last.to_s.downcase

    INTERNAL_EMAIL_DOMAINS.include?(domain)
  end
  private_class_method :internal_email?

  # Prefetch person docs keyed by normalized internal email.
  #
  # @param emails [Array<String>]
  # @return [Hash<String, Nokogiri::XML::Document|nil>]
  def self.prefetch_person_xml_docs(emails)
    normalized_internal_emails = Array(emails)
      .map { |email| email.to_s.strip.downcase }
      .reject(&:blank?)
      .uniq
      .select { |email| internal_email?(email) }

    return {} if normalized_internal_emails.empty?

    normalized_internal_emails.each_with_object({}) do |email, docs_by_email|
      docs_by_email[email] = person_xml_doc(email)
    end
  end

  ##
  # @param email [String] the email address of the person
  # @return [Nokogiri::XML::Document] the person XML document from the Illinois Experts System
  def self.person_xml_doc(email)
    raise ArgumentError.new("must provide email address string") unless email

    stripped_email = email.strip.downcase

    return nil if stripped_email.blank?
    return nil unless internal_email?(stripped_email)

    query = CGI.escape(stripped_email)
    uri = URI.parse("#{endpoint}/persons?apiKey=#{api_key}&size=1&q=#{query}")

    return nil unless uri.respond_to?(:request_uri)

    response = get_response(uri, { "Accept" => "application/json" })
    return nil if response.nil?

    case response
    when Net::HTTPSuccess, Net::HTTPCreated, Net::HTTPRedirection
      parse_person_xml_doc_from_json(response.body)
    end
  end

  # Backward-compatible alias used by the controller endpoint.
  #
  # @param email [String]
  # @return [Nokogiri::XML::Document, nil]
  def self.persons(email)
    person_xml_doc(email)
  end

  def self.get_response(uri, headers = {})
    request = Net::HTTP::Get.new(uri.request_uri)
    headers.each { |header_name, value| request.add_field(header_name, value) }

    retries = 0

    begin
      sock = Net::HTTP.new(uri.host, uri.port)
      sock.use_ssl = uri.scheme == "https"
      sock.open_timeout = OPEN_TIMEOUT_SECONDS
      sock.read_timeout = READ_TIMEOUT_SECONDS

      sock.start { |http| http.request(request) }
    rescue Net::OpenTimeout, Net::ReadTimeout, Net::HTTPBadResponse,
           Net::HTTPServerError, OpenSSL::SSL::SSLError, EOFError,
           Errno::ECONNRESET, SocketError
      retries += 1
      retry if retries < REQUEST_RETRIES
      nil
    end
  end
  private_class_method :get_response

  def self.parse_person_xml_doc_from_json(response_body)
    payload = JSON.parse(response_body)
    person = payload.fetch("items", []).first

    return nil if person.nil?

    build_person_xml_doc(person)
  rescue JSON::ParserError, KeyError
    nil
  end
  private_class_method :parse_person_xml_doc_from_json

  def self.build_person_xml_doc(person)
    doc = Nokogiri::XML::Document.new
    person_node = Nokogiri::XML::Node.new("person", doc)
    doc.root = person_node

    associations = person_associations(person)
    associations.each do |association|
      org_uuid = organization_uuid_for_association(association)

      next if org_uuid.blank?

      org_node = Nokogiri::XML::Node.new("organisationalUnit", doc)
      org_node["uuid"] = org_uuid
      person_node.add_child(org_node)
    end

    start_date_value = association_start_date(associations)
    if start_date_value.present?
      period_node = Nokogiri::XML::Node.new("period", doc)
      start_date_node = Nokogiri::XML::Node.new("startDate", doc)
      start_date_node.content = start_date_value
      period_node.add_child(start_date_node)
      person_node.add_child(period_node)
    end

    doc
  end
  private_class_method :build_person_xml_doc

  def self.person_associations(person)
    %w[
      staffOrganisationAssociations
      honoraryStaffOrganisationAssociations
      visitingScholarOrganisationAssociations
      studentOrganisationAssociations
      staffOrganizationAssociations
      honoraryStaffOrganizationAssociations
      visitingScholarOrganizationAssociations
      studentOrganizationAssociations
    ].flat_map { |key| person[key] || [] }
  end
  private_class_method :person_associations

  def self.organization_uuid_for_association(association)
    association.dig("organisationalUnit", "uuid") ||
      association.dig("organizationalUnit", "uuid") ||
      association.dig("organization", "uuid")
  end
  private_class_method :organization_uuid_for_association

  def self.association_start_date(associations)
    associations.each do |association|
      start_date = association.dig("period", "startDate")
      return start_date if start_date.present?
    end

    nil
  end
  private_class_method :association_start_date

  ##
  # @return [String] the example from the Illinois Experts System
  def self.example
    uri = URI.parse("#{endpoint}/datasets")

    response = get_response(uri, { "api-key" => api_key })
    return nil if response.nil?

    case response
    when Net::HTTPSuccess, Net::HTTPCreated, Net::HTTPRedirection
      response.body
    end
  end
end
