# frozen_string_literal: true

##
# This module provides methods for interacting with DataCite to reserve, register, and manage identifiers
# This module is included in the Dataset model

require "uri"
require "net/http"
require "base64"

module Dataset::Identifiable
  extend ActiveSupport::Concern

  URI_BASE ||= "https://#{IDB_CONFIG[:datacite][:endpoint]}/dois"
  CLIENT_ID ||= IDB_CONFIG[:datacite][:username]
  PASSWORD ||= IDB_CONFIG[:datacite][:password]

  private_constant :URI_BASE
  private_constant :CLIENT_ID
  private_constant :PASSWORD

  def draft_doi?
    datacite_state == Databank::DoiState::DRAFT
  end

  def registered_doi?
    # all findable dois are also registered
    [Databank::DoiState::REGISTERED, Databank::DoiState::FINDABLE].include?(datacite_state)
  end

  def findable_doi?
    datacite_state == Databank::DoiState::FINDABLE
  end

  def doi_state
    info = doi_infohash
    return Databank::DoiState::UNREGISTERED if info == {}

    raise StandardError.new("missing data element doi_state #{key}") unless info.has_key?(:data)
    raise StandardError.new("missing attribute element doi_state #{key}, info: #{info}") unless info[:data].has_key?(:attributes)
    raise StandardError.new("missing state element doi_state #{key}, info: #{info}") unless info[:data][:attributes].has_key?(:state)

    info[:data][:attributes][:state]
  end

  def default_identifier
    shoulder = if is_test?
              IDB_CONFIG[:datacite_test][:shoulder]
            else
              IDB_CONFIG[:datacite][:shoulder]
            end
    "#{shoulder}#{key}_V1"
  end

  def create_draft_doi
    return {status: "ok"} if Rails.env.development? || Rails.env.test?

    self.identifier ||= default_identifier
    save!

    # should not draft doi if doi record already exists in DataCite
    if !doi_infohash.empty? && doi_infohash.has_key?(:data)
      return error_hash("record already exists in DataCite for dataset #{key}")
    end

    # minimal json to create draft record
    draft_json = %({"data": {"type": "dois", "attributes": {"doi": "#{self.identifier}"}}})
    response = Dataset.post_to_datacite(draft_json)
    unless response.code == "201"
      return error_hash("problem attempting to create draft doi code: #{response.code}, #{response.body}")
    end

    {status: "ok"}
  end

  # publish - Triggers a state move to findable
  # should not be done for datasets with embargoed metadata
  def publish_doi
    return {status: "ok"} if Rails.env.development? || Rails.env.test?

    return error_hash("no identifier present") unless identifier_present?

    return error_hash("Cannot make dataset findable if metadata can not be public.") unless metadata_public?

    current_state = doi_state

    return update_doi if current_state == Databank::DoiState::FINDABLE

    if current_state.nil? || current_state == Databank::DoiState::UNREGISTERED
      draft_result = create_draft_doi
      return draft_result unless draft_result[:status] == "ok"

      sleep(1.5)
      current_state = doi_state
    end

    unless [Databank::DoiState::DRAFT, Databank::DoiState::REGISTERED].include?(current_state)
      return {status: "error", error_text: "invalid state for publish_doi, must be draft or registered, not: #{current_state}"}
    end

    publish_body = datacite_json_body(Databank::DoiEvent::PUBLISH)

    Dataset.put_to_datacite(identifier, publish_body)

    sleep(1.5)
    current_state = doi_state

    unless defined?(current_state) && current_state == Databank::DoiState::FINDABLE
      return {status: "error", error_text: "problem sending metadata to DataCite #{key}"}
    end

    {status: "ok"}
  end

  # register - Triggers a state move from draft to registered
  def register_doi
    return error_hash("no identifier present") unless identifier_present?

    current_state = doi_state || Databank::DoiState::UNREGISTERED
    if current_state == Databank::DoiState::REGISTERED
      if update(publication_state: publication_state)
        return {status: "ok"}
      else
        return error_hash("problem updating Illinois Data Bank dataset during doi registration #{key}")
      end
    end

    if current_state == Databank::DoiState::UNREGISTERED
      create_draft_doi
      sleep(1.5)
      return error_hash("problem creating draft #{key}") unless doi_state == Databank::DoiState::DRAFT
    end

    current_state = doi_state
    unless current_state == Databank::DoiState::DRAFT
      return("invalid DataCite state (#{current_state}) to register dataset: #{key}")
    end

    # DOI confirmed to be in a draft state with DataCite at this point
    Dataset.put_to_datacite(identifier, datacite_json_body(Databank::DoiEvent::REGISTER))
    sleep(1.5)
    current_state = doi_state
    unless current_state == Databank::DoiState::REGISTERED
      return error_hash("error while attempting to register with DataCite #{key}")
    end

    {status: "ok"}
  end

  # hide - Triggers a state move from findable to registered, or deletes draft
  def hide_doi
    return error_hash("no identifier present") unless identifier_present?

    current_state = doi_state

    case current_state
    when Databank::DoiState::UNREGISTERED, Databank::DoiState::REGISTERED
      return {status: "ok"}
    when Databank::DoiState::DRAFT
      return delete_doi
    when Databank::DoiState::FINDABLE
      Dataset.put_to_datacite(identifier, datacite_json_body(Databank::DoiEvent::HIDE))
      sleep(1.5)
    else
      return
    end

    if doi_state == Databank::DoiState::REGISTERED
      {status: "ok"}
    else
      error_hash("problem changing state in DataCite metadata store for dataset #{key}")
    end
  end

  # update_doi assumes that this dataset is in the correct publication state already
  def update_doi
    return error_hash("no identifier present") unless identifier_present?

    if doi_state == Databank::DoiState::FINDABLE && publication_state != Databank::PublicationState::RELEASED
      if update(publication_state: Databank::PublicationState::RELEASED)
        return {status: "ok"}
      else
        return error_hash("error updating Illinois Data Bank for dataset #{key}")
      end
    end

    response = Dataset.put_to_datacite(identifier, datacite_json_body(nil))
    return error_hash("error updating DataCite for #{key}") unless response

    return error_hash("error updating DataCite for #{key}, code: #{response.code}") unless response.code == "200"

    {status: "ok"}
  end

  def delete_doi
    return error_hash("no identifier present") unless identifier_present?

    current_state = doi_state
    case current_state
    when nil, Databank::DoiState::UNREGISTERED
      {status: "ok"}
    when Databank::DoiState::DRAFT
      url = URI("#{URI_BASE}/#{identifier}")
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      request = Net::HTTP::Delete.new(url)
      request["accept"] = "application/vnd.api+json"
      request["content-type"] = "application/vnd.api+json"
      request.basic_auth(CLIENT_ID, PASSWORD)
      request.body = json_body
      response = http.request(request)
      unless response.code == "204"
        return error_hash("error removing DOI from DataCite for #{key}, code: #{response.code}")
      end

      {status: "ok"}
    else
      error_hash("can only remove DataCite DOIs in draft state for #{key}, not: #{current_state}")
    end
  end

  def datacite_json_body(event)
    raise StandardError.new("identifier required for DataCite JSON body generation, key: #{key}") unless identifier_present?

    json_body = %({"data": {"id": "#{identifier}", "type": "dois", "attributes": {)
    json_body += %("event": "#{event}", ) if event.present?
    json_body += %("doi": "#{identifier}", "url": "#{databank_url}", )
    json_body + %("xml": "#{Base64.strict_encode64(to_datacite_xml)}"}}})
  end

  def to_datacite_xml
    s = [Databank::PublicationState::PermSuppress::METADATA, Databank::PublicationState::TempSuppress::METADATA]
    if s.include?(hold_state)
      withdrawn_datacite_xml
    elsif embargo == Databank::PublicationState::Embargo::METADATA && release_date > Time.current
      embargoed_datacite_xml
    else
      complete_datacite_xml
    end
  end

  def embargoed_datacite_xml
    raise "missing dataset identifier" unless identifier_present?

    release_date_valid = defined?(release_date) && release_date.present? && release_date.to_date > Date.current
    raise "missing release date for file and metadata publication delay for dataset #{key}" unless release_date_valid

    doc = Nokogiri::XML::Document.parse(datacite_xml_root_string)
    resource_node = doc.first_element_child

    identifier_node = doc.create_element("identifier")
    identifier_node["identifierType"] = "DOI"
    identifier_node.content = identifier
    identifier_node.parent = resource_node

    resource_type_node = doc.create_element("resourceType")
    resource_type_node["resourceTypeGeneral"] = "Dataset"
    resource_type_node.content = "Dataset"
    resource_type_node.parent = resource_node

    creators_node = doc.create_element("creators")
    creator_node = doc.create_element("creator")
    creator_name_node = doc.create_element("creatorName")
    creator_name_node.content = "[Embargoed]"
    creator_name_node.parent = creator_node
    creator_node.parent = creators_node
    creators_node.parent = resource_node

    titles_node = doc.create_element("titles")
    title_node = doc.create_element("title")
    title_node.content = "[Embargoed]"
    title_node.parent = titles_node
    titles_node.parent = resource_node

    publisher_node = doc.create_element("publisher")
    publisher_node.content = publisher || "University of Illinois Urbana-Champaign"
    publisher_node.parent = resource_node

    publication_year_node = doc.create_element("publicationYear")
    publication_year_node.content = publication_year || Time.now.in_time_zone.year
    publication_year_node.parent = resource_node

    descriptions_node = doc.create_element("descriptions")
    descriptions_node.parent = resource_node
    description_node = doc.create_element("description")
    description_node["descriptionType"] = "Other"
    description_string = "This dataset will be available #{release_date&.iso8601}. "
    description_string += "Contact us for more information. https://databank.illinois.edu/contact"
    description_node.content = description_string
    description_node.parent = descriptions_node

    dates_node = doc.create_element("dates")
    releasedate_node = doc.create_element("date")
    releasedate_node["dateType"] = "Available"
    releasedate_node.content = release_date&.iso8601
    releasedate_node.parent = dates_node
    dates_node.parent = resource_node

    doc.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML)
  end

  def datacite_xml_root_string
    root_string = %(<resource xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" )
    root_string += %(xmlns="http://datacite.org/schema/kernel-4" )
    root_string += %(xsi:schemaLocation="http://datacite.org/schema/kernel-4 )
    root_string += %(http://schema.datacite.org/meta/kernel-4.5/metadata.xsd">)
    root_string + %(</resource>)
  end

  def withdrawn_datacite_xml
    raise "cannot withdraw metadata from DataCite w/o identifier, dataset: #{key}" unless identifier_present?

    doc = Nokogiri::XML::Document.parse(datacite_xml_root_string)
    resource_node = doc.first_element_child

    identifier_node = doc.create_element("identifier")
    identifier_node["identifierType"] = "DOI"
    identifier_node.content = identifier
    identifier_node.parent = resource_node

    resource_type_node = doc.create_element("resourceType")
    resource_type_node["resourceTypeGeneral"] = "Dataset"
    resource_type_node.content = "Dataset"
    resource_type_node.parent = resource_node

    creators_node = doc.create_element("creators")
    creator_node = doc.create_element("creator")
    creator_name_node = doc.create_element("creatorName")
    creator_name_node.content = "[Redacted]"
    creator_name_node.parent = creator_node
    creator_node.parent = creators_node
    creators_node.parent = resource_node

    titles_node = doc.create_element("titles")
    title_node = doc.create_element("title")
    title_node.content = "[Redacted]"
    title_node.parent = titles_node
    titles_node.parent = resource_node

    publisher_node = doc.create_element("publisher")
    publisher_node.content = publisher || "University of Illinois Urbana-Champaign"
    publisher_node.parent = resource_node

    publication_year_node = doc.create_element("publicationYear")
    publication_year_node.content = publication_year || Time.now.in_time_zone.year
    publication_year_node.parent = resource_node

    descriptions_node = doc.create_element("descriptions")
    description_node = doc.create_element("description")
    description_node["descriptionType"] = "Other"
    description_node.content = "Removed by Illinois Data Bank curators. Contact us for more information. https://databank.illinois.edu/contact"
    description_node.parent = descriptions_node
    descriptions_node.parent = resource_node

    dates_node = doc.create_element("dates")
    releasedate_node = doc.create_element("date")
    releasedate_node["dateType"] = "Available"
    releasedate_node.content = release_date.iso8601
    releasedate_node.parent = dates_node
    withdrawn_date_node = doc.create_element("date")
    withdrawn_date_node["dateType"] = "Withdrawn"
    withdrawn_date_node.content = tombstone_date&.iso8601 || Date.current.iso8601
    withdrawn_date_node.parent = dates_node
    dates_node.parent = resource_node

    doc.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML)
  end

  def complete_datacite_xml
    raise "cannot generate DataCite metadata w/o identifier, dataset: #{key}" unless identifier_present?

    release_date_valid = defined?(release_date) && release_date.present?
    raise "missing release date for published dataset #{key}" unless release_date_valid

    contact = Creator.find_by(dataset_id: id, is_contact: true)
    raise StandardError.new("cannot generate DataCite metadata xml without contact, dataset: #{key}") unless contact

    doc = Nokogiri::XML::Document.parse(datacite_xml_root_string)
    resource_node = doc.first_element_child

    identifier_node = doc.create_element("identifier")
    identifier_node["identifierType"] = "DOI"
    identifier_node.parent = resource_node

    titles_node = doc.create_element("titles")
    title_node = doc.create_element("title")
    title_node.content = title
    title_node.parent = titles_node
    titles_node.parent = resource_node

    creators_node = doc.create_element("creators")
    creators.each do |creator|
      creator_node = doc.create_element("creator")
      if creator.type_of == Databank::CreatorType::PERSON
        creator_name_node = doc.create_element("creatorName")
        creator_name_node["nameType"] = "Personal"
        creator_name_node.content = creator.list_name
        creator_name_node.parent = creator_node
        given_name_node = doc.create_element("givenName")
        given_name_node.content = creator.given_name
        given_name_node.parent = creator_node
        family_name_node = doc.create_element("familyName")
        family_name_node.content = creator.family_name
        family_name_node.parent = creator_node
        # ORCID assumption hard-coded here, but in the model there is a field for identifier_scheme
        if creator.identifier.present?
          creator_identifier_node = doc.create_element("nameIdentifier")
          creator_identifier_node["schemeURI"] = "http://orcid.org/"
          creator_identifier_node["nameIdentifierScheme"] = "ORCID"
          creator_identifier_node.content = creator.identifier.to_s
          creator_identifier_node.parent = creator_node
        end
        if creator.email[-12..] == "illinois.edu"
          affiliation_node = doc.create_element("affiliation")
          affiliation_node["affiliationIdentifier"] = "https://ror.org/047426m28"
          affiliation_node["affiliationIdentifierScheme"] = "ROR"
          affiliation_node.content = "University of Illinois"
          affiliation_node.parent = creator_node
        end
      elsif creator.type_of == Databank::CreatorType::INSTITUTION
        creator_name_node = doc.create_element("creatorName")
        creator_name_node["nameType"] = "Organizational"
        creator_name_node.content = creator.list_name
        creator_name_node.parent = creator_node
      end
      creator_node.parent = creators_node
    end
    creators_node.parent = resource_node

    contributors_node = doc.create_element("contributors")

    contact_node = doc.create_element("contributor")
    contact_node["contributorType"] = "ContactPerson"

    if contact.type_of == Databank::CreatorType::PERSON
      contact_name_node = doc.create_element("contributorName")
      contact_name_node["nameType"] = "Personal"
      contact_name_node.content = contact.list_name
      contact_name_node.parent = contact_node
      given_name_node = doc.create_element("givenName")
      given_name_node.content = contact.given_name
      given_name_node.parent = contact_node
      family_name_node = doc.create_element("familyName")
      family_name_node.content = contact.family_name
      family_name_node.parent = contact_node
    elsif contact.type_of == Databank::CreatorType::INSTITUTION
      contact_name_node = doc.create_element("contributorName")
      contact_name_node["nameType"] = "Organizational"
      contact_name_node.content = contact.list_name
      contact_name_node.parent = contact_node
    end

    if contact.identifier && contact.identifier != ""
      contact_identifier_node = doc.create_element("nameIdentifier")
      contact_identifier_node["schemeURI"] = "http://orcid.org/"
      contact_identifier_node["nameIdentifierScheme"] = "ORCID"
      contact_identifier_node.content = contact.identifier.to_s
      contact_identifier_node.parent = contact_node
    end
    contact_node.parent = contributors_node

    if contributors.count.positive?
      contributors.each do |contributor|
        contributor_node = doc.create_element("contributor")
        contributor_node["contributorType"] = "ContactPerson"
        if contributor.type_of == Databank::CreatorType::PERSON
          contributor_name_node = doc.create_element("contributorName")
          contributor_name_node["nameType"] = "Personal"
          contributor_name_node.content = contributor.list_name
          contributor_name_node.parent = contributor_node
          given_name_node = doc.create_element("givenName")
          given_name_node.content = contributor.given_name
          given_name_node.parent = contributor_node
          family_name_node = doc.create_element("familyName")
          family_name_node.content = contributor.family_name
          family_name_node.parent = contributor_node
        elsif contributor.type_of == Databank::CreatorType::INSTITUTION
          contributor_name_node = doc.create_element("contributorName")
          contributor_name_node["nameType"] = "Organizational"
          contributor_name_node.content = contributor.list_name
          contributor_name_node.parent = contributor_node
        end

        # ORCID assumption hard-coded here, but in the model there is a field for identifier_scheme
        if contributor.identifier.present?
          contributor_identifier_node = doc.create_element("nameIdentifier")
          contributor_identifier_node["schemeURI"] = "http://orcid.org/"
          contributor_identifier_node["nameIdentifierScheme"] = "ORCID"
          contributor_identifier_node.content = contributor.identifier.to_s
          contributor_identifier_node.parent = contributor_node
        end
        contributor_node.parent = contributors_node
      end
    end
    contributors_node.parent = resource_node

    if funders.count.positive?
      funding_references_node = doc.create_element("fundingReferences")
      funders.each do |funder|
        funding_reference_node = doc.create_element("fundingReference")
        funder_name_node = doc.create_element("funderName")
        funder_name_node.content = funder.name || "Funder"
        funder_name_node.parent = funding_reference_node
        if funder.identifier.present?
          funder_identifier_node = doc.create_element("funderIdentifier")
          funder_identifier_node["funderIdentifierType"] = "Crossref Funder ID"
          funder_identifier_node.content = "https://doi.org/#{funder.identifier}"
          funder_identifier_node.parent = funding_reference_node
        end
        if funder.grant.present?
          award_number_node = doc.create_element("awardNumber")
          award_number_node.content = funder.grant
          award_number_node.parent = funding_reference_node
        end
        funding_reference_node.parent = funding_references_node
      end
      funding_references_node.parent = resource_node
    end

    publisher_node = doc.create_element("publisher")
    publisher_node.content = publisher || "University of Illinois Urbana-Champaign"
    publisher_node.parent = resource_node

    publication_year_node = doc.create_element("publicationYear")
    publication_year_node.content = publication_year || Time.now.in_time_zone.year
    publication_year_node.parent = resource_node

    resource_type_node = doc.create_element("resourceType")
    resource_type_node["resourceTypeGeneral"] = "Dataset"
    resource_type_node.content = "Dataset"
    resource_type_node.parent = resource_node

    keyword_arr = keywords.split(";") if defined?(keywords) && keywords.present?
    keyword_arr ||= []
    if keyword_arr.length.positive?
      subjects_node = doc.create_element("subjects")
      keyword_arr.each do |keyword|
        subject_node = doc.create_element("subject")
        subject_node.content = keyword.strip
        subject_node.parent = subjects_node
      end
      subjects_node.parent = resource_node
    end

    dates_node = doc.create_element("dates")
    releasedate_node = doc.create_element("date")
    releasedate_node["dateType"] = "Available"
    releasedate_node.content = release_date.iso8601
    releasedate_node.parent = dates_node
    dates_node.parent = resource_node

    version_node = doc.create_element("version")
    version_node.content = dataset_version || "1"
    version_node.parent = resource_node

    if defined?(license) && license.present? && ["CC01", "CCBY4", "license.txt"].include?(license)
      rights_list_node = doc.create_element("rightsList")
      rights_node = doc.create_element("rights")
      case license
      when "CC01"
        rights_node["rightsURI"] = "https://creativecommons.org/publicdomain/zero/1.0/"
        rights_node.content = "CC0 1.0 Universal Public Domain Dedication (CC0 1.0)"
        rights_node.parent = rights_list_node
        rights_list_node.parent = resource_node
      when "CCBY4"
        rights_node["rightsURI"] = "http://creativecommons.org/licenses/by/4.0/"
        rights_node.content = "Creative Commons Attribution 4.0 International (CC BY 4.0)"
        rights_node.parent = rights_list_node
        rights_list_node.parent = resource_node
      when "license.txt"
        rights_node.content = "See license.txt in dataset"
        rights_node.parent = rights_list_node
        rights_list_node.parent = resource_node
      end
    end

    if defined?(description) && description.present?
      descriptions_node = doc.create_element("descriptions")
      descriptions_node.parent = resource_node
      description_node = doc.create_element("description")
      description_node["descriptionType"] = "Abstract"
      description_node.content = description
      description_node.parent = descriptions_node
    end

    if related_materials.count.positive?
      ready_count = 0
      related_identifiers_node = doc.create_element("relatedIdentifiers")
      related_identifiers_node.parent = resource_node
      related_materials.each do |material|
        next unless material.uri && material.uri != ""

        datacite_arr = []
        if material.datacite_list && material.datacite_list != ""
          datacite_arr = material.datacite_list.split(",")
        else
          datacite_arr << "IsSupplementTo"
        end
        datacite_arr.each do |relationship|
          ready_count += 1
          related_material_node = doc.create_element("relatedIdentifier")
          related_material_node["relatedIdentifierType"] = material.uri_type || "URL"
          related_material_node["relationType"] = relationship.strip
          related_material_node.content = material.uri
          related_material_node.parent = related_identifiers_node
        end
      end
      related_identifiers_node.remove if ready_count.zero?
    end
    doc.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML)
  end

  ##
  # @return [String] the DataCite XML for the dataset
  # @note this method is used to generate the DataCite XML for the dataset
  def to_datacite_raw_xml
    Nokogiri::XML::Document.parse(to_datacite_xml).to_xml
  end

  def doi_infohash
    response = doi_info_from_datacite

    raise StandardError.new("no response to doi info call") unless response

    case response

    when Net::HTTPUnauthorized
      raise StandardError.new("credentials could not be verified")
    when Net::HTTPUnprocessableEntity
      raise StandardError.new("bad get_doi request for dataset: #{key}")
    when Net::HTTPNotFound
      {}
    when Net::HTTPSuccess, Net::HTTPRedirection
      response_body = response.body
      raise StandardError.new("response not valid JSON: #{response_body}") unless json?(response_body)

      JSON.parse(response_body, symbolize_names: true)
    else
      raise StandardError.new("unexpected response from DataCite for #{doi}: #{response.body}")
    end
  end

  class_methods do
    def post_to_datacite(json_body)
      url = URI(URI_BASE)
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      request = Net::HTTP::Post.new(url)
      request["accept"] = "application/vnd.api+json"
      request["content-type"] = "application/vnd.api+json"
      request.basic_auth(CLIENT_ID, PASSWORD)
      request.body = json_body
      response = http.request(request)

      case response
      when Net::HTTPUnauthorized
        Rails.logger.warn("#{response.code}, #{response.body}, #{json_body}")
        nil
      when Net::HTTPUnprocessableEntity, Net::HTTPNotFound
        Rails.logger.warn("#{response.code}, #{response.body}, #{json_body}")
        nil
      when Net::HTTPSuccess, Net::HTTPRedirection
        response
      else
        Rails.logger.warn("#{response.code}, #{response.body}, #{json_body}")
        nil
      end
    end

    def put_to_datacite(identifier, json_body)
      url = URI("#{URI_BASE}/#{identifier}")
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      request = Net::HTTP::Put.new(url)
      request["accept"] = "application/vnd.api+json"
      request["content-type"] = "application/vnd.api+json"
      request.basic_auth(CLIENT_ID, PASSWORD)
      request.body = json_body
      response = http.request(request)

      case response
      when Net::HTTPUnauthorized
        Rails.logger.warn("#{response.code}, #{response.body}, #{json_body}")
        nil
      when Net::HTTPUnprocessableEntity, Net::HTTPNotFound
        Rails.logger.warn("#{response.code}, #{response.body}, #{json_body}")
        nil
      when Net::HTTPSuccess, Net::HTTPRedirection
        response
      else
        Rails.logger.warn("#{response.code}, #{response.body}, #{json_body}")
        nil
      end
    end
  end

  private

  def identifier_present?
    return false unless defined?(identifier)

    identifier.present?
  end

  def doi_info_from_datacite
    raise StandardError.new("cannot get information from DataCite without identifier for #{key}") unless identifier_present?

    url = URI("#{URI_BASE}/#{identifier.downcase}")
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Get.new(url)
    request["accept"] = "application/vnd.api+json"
    request.basic_auth(CLIENT_ID, PASSWORD)
    http.request(request)
  end

  def json?(string)
    JSON.parse(string)
    true
  rescue JSON::ParserError
    false
  end
end
