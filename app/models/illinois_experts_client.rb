# frozen_string_literal: true

##
# Represents a client used to interact with the Illinois Experts API
# Used to generate a document consumed by the Illinois Experts System
# Gets information about a person from the Illinois Experts System

require "nokogiri"
require "open-uri"

class IllinoisExpertsClient
  include ActiveModel::Conversion
  include ActiveModel::Naming

  ENDPOINT = IDB_CONFIG[:illinois_experts][:endpoint]
  KEY = IDB_CONFIG[:illinois_experts][:key]
  private_constant :ENDPOINT
  private_constant :KEY

  ##
  # @param email [String] the email address of the person
  # @return [Nokogiri::XML::Document] the person XML document from the Illinois Experts System
  def self.person_xml_doc(email)
    raise ArgumentError.new("must provide email address string") unless email

    stripped_email = email.strip

    encoded_email = CGI.escape(stripped_email)

    uri = URI.parse("#{ENDPOINT}/persons/#{encoded_email}?apiKey=#{KEY}")

    return nil unless uri.respond_to?(:request_uri)

    request = Net::HTTP::Get.new(uri.request_uri)
    sock = Net::HTTP.new(uri.host, uri.port)
    sock.set_debug_output $stderr
    sock.use_ssl = true

    begin
      response = sock.start {|http| http.request(request) }
    rescue Net::HTTPBadResponse, Net::HTTPServerError
      return nil
    end

    case response
    when Net::HTTPSuccess, Net::HTTPCreated, Net::HTTPRedirection
      begin
        doc = Nokogiri::XML(response.body)
        doc.remove_namespaces!
        doc
      rescue Nokogiri::XML::SyntaxError
        nil
      end
    end
  end

  ##
  # @return [String] the example from the Illinois Experts System
  def self.example
    uri = URI.parse("#{ENDPOINT}/datasets")

    request = Net::HTTP::Get.new(uri.request_uri)
    request.add_field("api-key", KEY)

    sock = Net::HTTP.new(uri.host, uri.port)
    sock.set_debug_output $stderr
    sock.use_ssl = true

    begin
      response = sock.start {|http| http.request(request) }
    rescue Net::HTTPBadResponse, Net::HTTPServerError
      return nil
    end

    case response
    when Net::HTTPSuccess, Net::HTTPCreated, Net::HTTPRedirection
      response.body
    end
  end
end
