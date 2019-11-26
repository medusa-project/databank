# frozen_string_literal: true

require 'nokogiri'
require 'open-uri'

class IllinoisExpertsClient
  include ActiveModel::Conversion
  include ActiveModel::Naming

  ENDPOINT = IDB_CONFIG[:illinois_experts][:endpoint]
  KEY = IDB_CONFIG[:illinois_experts][:key]
  private_constant :ENDPOINT
  private_constant :KEY

  def self.person_xml_doc(email)
    raise ArgumentError.new("must provide email address string") unless email

    stripped_email = email.strip

    encoded_email = CGI.escape(stripped_email)

    uri = URI.parse("#{ENDPOINT}/persons?q=#{encoded_email}&apiKey=#{KEY}")

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
        count = doc.xpath("//count").first.content
        return nil unless count.to_i > 0

        return IllinoisExpertsClient.exact_match(stripped_email, doc)

      rescue Nokogiri::XML::SyntaxError
        return nil
      end
    else
      return nil
    end
  end

  def self.exact_match(email, doc)
    items = doc.xpath("//items")
    items.each do |item_node|
      external_id = item_node.attr('externalId')
      return item if external_id == email
    end
    nil
  end

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
      return response.body
    else
      return nil
    end
  end

end
