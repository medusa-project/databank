# frozen_string_literal: true

##
# Supports exporting datasets to Illinois Experts
# generates an XML section for each dataset
# with metadata and creators
# The Illinois Experts API is used to get information about creators, if they are internal
#
# The XML document is a string that is written to a file
# which is read by Illinois Experts
# This module is included in the Dataset model.

module Dataset::Exportable
  extend ActiveSupport::Concern

  class_methods do
    def to_illinois_experts
      datasets = Dataset.where(is_test: false).where(org_creators: false).select(&:metadata_public?)

      return nil unless datasets.count.positive?

      root_string = %(<v1:datasets xmlns:v1="v1.dataset.pure.atira.dk" xmlns:v3="v3.commons.pure.atira.dk"></datasets>)
      doc = Nokogiri::XML::Document.parse(root_string)
      datasets_node = doc.first_element_child
      datasets.each do |dataset|
        dataset_node = doc.create_element("v1:dataset")
        dataset_node["id"] = "doi:#{dataset.identifier}"
        dataset_node["type"] = "dataset"
        dataset_node.parent = datasets_node
        title_node = doc.create_element("v1:title")
        title_node.content = dataset.title
        title_node.parent = dataset_node
        managing_org_node = doc.create_element("v1:managingOrganisation")
        managing_org_node["lookupId"] = IDB_CONFIG[:illinois_experts][:org_id]
        managing_org_node.parent = dataset_node
        if dataset.description.present?
          description_node = doc.create_element("v1:description")
          description_node.content = dataset.description
          description_node.parent = dataset_node
        end
        persons_node = doc.create_element("v1:persons")

        dataset_release_date = dataset.release_date || Time.zone.today

        dataset.individual_creators.each do |creator|
          next if creator.email.strip == ""

          person_xml_doc = IllinoisExpertsClient.person_xml_doc(creator.email)
          person_node = if !person_xml_doc.nil?
                          internal_expert(doc, creator, person_xml_doc, dataset_release_date)
                        elsif creator.at_illinois?
                          illinois_external_expert(doc, creator, dataset_release_date)
                        else
                          external_expert(doc, creator, dataset_release_date)
                        end
          person_node.parent = persons_node
        end
        persons_node.parent = dataset_node
        doi_node = doc.create_element("v1:DOI")
        doi_node.content = dataset.identifier
        doi_node.parent = dataset_node
        release_date = dataset.release_date || Time.zone.today
        available_node = doc.create_element("v1:availableDate")
        year_node = doc.create_element("v3:year")
        year_node.content = release_date.strftime("%Y")
        year_node.parent = available_node
        month_node = doc.create_element("v3:month")
        month_node.content = release_date.strftime("%m")
        month_node.parent = available_node
        day_node = doc.create_element("v3:day")
        day_node.content = release_date.strftime("%d")
        day_node.parent = available_node
        available_node.parent = dataset_node
        publisher_node = doc.create_element("v1:publisher")
        publisher_node["lookupId"] = IDB_CONFIG[:illinois_experts][:publisher_id]
        publisher_node.parent = dataset_node
        next if dataset.keywords.blank?

        keywords_node = doc.create_element("v1:keywords")
        keywords = dataset.keywords.split(";")
        keywords = keywords.map(&:squish)
        keywords.each do |keyword|
          keyword_node = doc.create_element("v1:keyword")
          keyword_node.content = keyword
          keyword_node.parent = keywords_node
        end
        keywords_node.parent = dataset_node
      end
      doc.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML)
    end

    def internal_expert(doc, creator, person_xml_doc, dataset_release_date)
      person_node = doc.create_element("v1:person")
      person_node["id"] = creator.email
      person_node["contactPerson"] = "true" if creator.is_contact
      role_node = doc.create_element("v1:role")
      role_node.content = "creator"
      role_node.parent = person_node
      nested_person_node = doc.create_element("v1:person")
      nested_person_node["lookupId"] = creator.email
      nested_person_node.parent = person_node
      organisations_node = doc.create_element("v1:organisations")
      org_uuids = person_xml_doc.xpath("//organisationalUnit/@uuid")
      if org_uuids.empty?
        organization_node = doc.create_element("v1:organisation")
        organization_node["lookupId"] = IDB_CONFIG[:illinois_experts][:publisher_id]
        organization_node.parent = organisations_node
      else
        org_uuids.each do |org_uuid|
          organization_node = doc.create_element("v1:organisation")
          organization_node["lookupId"] = org_uuid.content
          organization_node.parent = organisations_node
        end
      end
      organisations_node.parent = person_node
      date_node = doc.create_element("v1:associationStartDate")
      start_date_nodeset = person_xml_doc.xpath("//period/startDate")
      date_node.content = if start_date_nodeset.empty?
                            dataset_release_date.strftime("%Y-%m-%d")
                          else
                            start_date_nodeset.first.content
                          end
      date_node.parent = person_node
      person_node
    end

    def external_expert(doc, creator, dataset_release_date)
      person_node = doc.create_element("v1:person")
      person_node["id"] = creator.email
      role_node = doc.create_element("v1:role")
      role_node.content = "creator"
      role_node.parent = person_node
      nested_person_node = doc.create_element("v1:person")
      nested_person_node["origin"] = "external"
      first_name_node = doc.create_element("v1:firstName")
      first_name_node.content = creator.given_name
      first_name_node.parent = nested_person_node
      last_name_node = doc.create_element("v1:lastName")
      last_name_node.content = creator.family_name
      last_name_node.parent = nested_person_node
      nested_person_node.parent = person_node
      organisations_node = doc.create_element("v1:organisations")
      organization_node = doc.create_element("v1:organisation")
      org_name_node = doc.create_element("v1:name")
      org_name_node.content = "unknown"
      org_name_node.parent = organization_node
      organization_node.parent = organisations_node
      organisations_node.parent = person_node
      date_node = doc.create_element("v1:associationStartDate")
      date_node.content = dataset_release_date.strftime("%Y-%m-%d")
      date_node.parent = person_node
      person_node
    end

    def illinois_external_expert(doc, creator, dataset_release_date)
      person_node = doc.create_element("v1:person")
      person_node["id"] = creator.email
      role_node = doc.create_element("v1:role")
      role_node.content = "creator"
      role_node.parent = person_node
      nested_person_node = doc.create_element("v1:person")
      nested_person_node["origin"] = "external"
      first_name_node = doc.create_element("v1:firstName")
      first_name_node.content = creator.given_name
      first_name_node.parent = nested_person_node
      last_name_node = doc.create_element("v1:lastName")
      last_name_node.content = creator.family_name
      last_name_node.parent = nested_person_node
      nested_person_node.parent = person_node
      organisations_node = doc.create_element("v1:organisations")
      organization_node = doc.create_element("v1:organisation")
      organization_node["lookupId"] = IDB_CONFIG[:illinois_experts][:illinois_external_org_id]
      organization_node.parent = organisations_node
      organisations_node.parent = person_node
      date_node = doc.create_element("v1:associationStartDate")
      date_node.content = dataset_release_date.strftime("%Y-%m-%d")
      date_node.parent = person_node
      person_node
    end
  end
end
