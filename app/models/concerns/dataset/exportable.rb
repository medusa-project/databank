# frozen_string_literal: true

module Exportable
  extend ActiveSupport::Concern

  class_methods do
    def to_illinois_experts

      datasets = Dataset.where(is_test: false).where(org_creators: false).select(&:metadata_public?)

      return nil unless datasets.count.positive?

      root_string = %Q(<v1:datasets xmlns:v1="v1.dataset.pure.atira.dk" xmlns:v3="v3.commons.pure.atira.dk"></datasets>)
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
        if dataset.description && !dataset.description.empty?
          descriptions_node = doc.create_element("v1:descriptions")
          description_node = doc.create_element("v1:description")
          description_node.content = dataset.description
          description_node.parent = descriptions_node
          descriptions_node.parent = dataset_node
        end
        persons_node = doc.create_element("v1:persons")
        dataset.individual_creators.each do |creator|

          person_hash = IllinoisExpertsClient.person_hash(creator.email)
          next unless person_hash

          person_node = doc.create_element("v1:person")
          person_node['lookupId'] = creator.email
          role_node = doc.create_element("v1:role")
          role_node.content = "creator"
          role_node.parent = person_node
          if person_hash && !person_hash[:email].nil? && creator.at_illinois?
              person_node['lookupHint'] = "synchronisedPerson"
          else
              person_node['origin'] = "external"
          end
          first_name_node = doc.create_element("v1:firstName")
          first_name_node.content = creator.given_name
          first_name_node.parent = person_node
          last_name_node = doc.create_element("v1:lastName")
          last_name_node.content = creator.family_name
          last_name_node.parent = person_node
          person_node['contactPerson'] = "true" if creator.is_contact

          organisations_node = doc.create_element("v1:organisations")
          organization_node = doc.create_element("v1:organization")
          org_name_node = doc.create_element("v1:name")
          org_name_node.content = person_hash['org']
          org_name_node.parent = organization_node
          organization_node.parent = organisations_node
          organisations_node.parent = person_node

          person_node.parent = persons_node

        end
        persons_node.parent = dataset_node

        doi_node = doc.create_element("v1:DOI")
        doi_node.content = dataset.identifier
        doi_node.parent = dataset_node

        available_node = doc.create_element("v1:availableDate")
        year_node = doc.create_element("v1:year")
        year_node.content = dataset.publication_year
        year_node.parent = available_node
        available_node.parent = dataset_node

        publisher_node = doc.create_element("v1:publisher")
        publisher_node["lookupId"]=IDB_CONFIG[:illinois_experts][:publisher_id]
        publisher_node.parent = dataset_node

      end
      doc.to_xml(:save_with => Nokogiri::XML::Node::SaveOptions::AS_XML)
    end
  end

end
