# frozen_string_literal: true

module Dataset::Versionable
  extend ActiveSupport::Concern
  def version_group
    self_version_entry = related_version_entry_hash
    self_version_entry[:selected] = true

    version_group_response = {status: "ok", entries: [self_version_entry]}

    # follow daisy chain of previous versions
    current_dataset = self

    current_group_count = 0
    max_group_count = 50

    while current_dataset && current_group_count < max_group_count
      current_group_count += 1
      previous_dataset = current_dataset.previous_idb_dataset
      break if previous_dataset == current_dataset

      version_group_response[:entries] << previous_dataset.related_version_entry_hash if previous_dataset
      current_dataset = previous_dataset
    end

    # reset pointer for chain of next versions
    current_dataset = self
    current_group_count = 0

    while current_dataset

      current_group_count += 1

      next_dataset = current_dataset.next_idb_dataset

      break if next_dataset == current_dataset

      version_group_response[:entries] << next_dataset.related_version_entry_hash if next_dataset

      # go to next, if it exists, else set control to nil and break
      current_dataset = next_dataset

    end

    (version_group_response[:entries].sort_by! {|k| k[:version] }).reverse!
    version_group_response
  end

  def related_version_entry_hash
    # version group is an array of hashes
    self_version = dataset_version.to_i

    self_version = 1 if !self_version || self_version < 1

    {version:          self_version,
     selected:         false,
     doi:              identifier || "not yet set",
     version_comment:  version_comment || "",
     publication_date: release_date ? release_date.iso8601 : "not yet set"}
  end

  def is_most_recent_version
    if !version_group.empty?
      (version_group[:entries][0])[:version] == dataset_version.to_i
    else
      true
    end
  end

  def eligible_for_version?
    is_most_recent_version && Databank::PublicationState::PUB_ARRAY.include?(publication_state)
  end

  def send_version_request_emails
    request_version_email = DatabankMailer.request_version(key)
    request_version_email.deliver_now
    acknowledge_request_version_email = DatabankMailer.acknowledge_request_version(key)
    acknowledge_request_version_email.deliver_now
  end
  def add_version_nested_objects(previous:)
    previous.creators.each do |creator|
      Creator.create(dataset_id: self.id,
                     family_name: creator.family_name,
                     given_name: creator.given_name,
                     institution_name: creator.institution_name,
                     identifier: creator.identifier,
                     type_of: creator.type_of,
                     row_order: creator.row_order,
                     email: creator.email,
                     is_contact: creator.is_contact,
                     row_position: creator.row_position,
                     identifier_scheme: creator.identifier_scheme)
    end

    previous.funders.each do |funder|
      Funder.create(dataset_id: self.id,
                    name: funder.name,
                    identifier: funder.identifier,
                    identifier_scheme: funder.identifier_scheme,
                    grant: funder.grant,
                    code: funder.code)
    end

    previous.related_materials.each do |material|
      RelatedMaterial.create(dataset_id: self.id,
                             material_type: material.material_type,
                             availability: material.availability,
                             link: material.link,
                             uri: material.uri,
                             citation: material.citation,
                             selected_type: material.selected_type,
                             datacite_list: material.datacite_list,
                             feature: material.feature,
                             note: material.note)
    end
    save
  end

  def is_unconfirmed_version?
    publication_state == Databank::PublicationState::TempSuppress::VERSION || hold_state == Databank::PublicationState::TempSuppress::VERSION
  end
  def add_version_relationships(previous:)
    RelatedMaterial.create(dataset_id: self.id,
                           material_type: Databank::MaterialType::DATASET,
                           selected_type: Databank::MaterialType::DATASET,
                           datacite_list: Databank::Relationship::NEW_VERSION_OF,
                           uri: previous.identifier,
                           uri_type: "DOI",
                           citation: previous.plain_text_citation,
                           link: "https://doi.org/#{previous.identifier}")
    RelatedMaterial.create(dataset_id: previous.id,
                           material_type: Databank::MaterialType::DATASET,
                           selected_type: Databank::MaterialType::DATASET,
                           datacite_list: Databank::Relationship::PREVIOUS_VERSION_OF,
                           uri: self.identifier,
                           uri_type: "DOI",
                           citation: self.plain_text_citation,
                           link: "https://doi.org/#{self.identifier}")
  end

  def add_version_files(previous:)
    previous.datafiles.each do |datafile|
      VersionFile.create(dataset_id: self.id, datafile_id: datafile.id, selected: false)
    end
  end
  def previous_idb_dataset
    previous_version_related_material = related_materials.find_by(datacite_list: Databank::Relationship::NEW_VERSION_OF)

    return nil unless previous_version_related_material&.uri

    Dataset.find_by(identifier: previous_version_related_material.uri)
  end

  def next_idb_dataset
    next_version_material = related_materials.find_by(datacite_list: Databank::Relationship::PREVIOUS_VERSION_OF)

    return nil unless next_version_material&.uri

    Dataset.find_by(identifier: next_version_material.uri)
  end
end
