# frozen_string_literal: true

module Dataset::Versionable
  extend ActiveSupport::Concern
  attr_accessor :version_group

  def version_copies_complete?
    version_files.each do |version_file|
      return false unless version_file.complete?
    end
    true
  end

  def version_copies_initiated?
    version_files.each do |version_file|
      return true if version_file.initiated?
    end
    false
  end

  def copy_version_files
    files_to_copy = version_files.where(selected: true, initiated: false)
    files_to_copy.each do |file_to_copy|
      file_to_copy.update_attribute(:initiated, true)
    end
    files_to_copy.each(&:copy_file)
    files_copied_email = DatabankMailer.notify_version_copy_complete(dataset_key: key)
    files_copied_email.deliver_now
  end

  def related_version_entry_hash
    # version_group[:group_hash] is an array of hashes
    self_version = dataset_version.to_i

    self_version = 1 if !self_version || self_version < 1

    {version:          self_version,
     selected:         false,
     doi:              identifier || "not yet set",
     version_comment:  version_comment || "",
     publication_date: release_date ? release_date.iso8601 : "not yet set"}
  end

  def ensure_version_group
    self.version_group ||= VersionGroup.new(self)
  end

  def update_version_group
    self.version_group = VersionGroup.new(self)
  end

  def has_newer_version?
    ensure_version_group
    self.version_group.group_hash[:entries].length > 1 &&
      dataset_version.to_i.positive? &&
      (self.version_group.group_hash[:entries][0][:version]).to_i > dataset_version.to_i
  end

  def version_eligible_for_review?
    publication_state == Databank::PublicationState::TempSuppress::VERSION &&
      hold_state == Databank::PublicationState::TempSuppress::NONE
  end

  def is_most_recent_version
    return false if publication_state == Databank::PublicationState::TempSuppress::VERSION

    ensure_version_group
    if self.version_group.group_hash[:entries].length > 1
      (version_group.group_hash[:entries][0])[:version] == dataset_version.to_i
    else
      true
    end
  end

  def eligible_for_version?
    is_most_recent_version &&
      Databank::PublicationState::PUB_ARRAY.include?(publication_state) &&
      next_idb_dataset.nil?
  end

  def send_version_request_emails
    request_version_email = DatabankMailer.request_version(dataset_key: key)
    request_version_email.deliver_now
    acknowledge_request_version_email = DatabankMailer.acknowledge_request_version(dataset_key: key)
    acknowledge_request_version_email.deliver_now
  end

  def add_version_nested_objects(previous:)
    return true if creators.count.positive?

    previous.creators.each do |creator|
      Creator.create(dataset_id: id,
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
      Funder.create(dataset_id: id,
                    name: funder.name,
                    identifier: funder.identifier,
                    identifier_scheme: funder.identifier_scheme,
                    grant: funder.grant,
                    code: funder.code)
    end

    previous.related_materials.each do |material|
      next if material.datacite_list == Databank::Relationship::NEW_VERSION_OF
      next if material.datacite_list == Databank::Relationship::PREVIOUS_VERSION_OF

      RelatedMaterial.create(dataset_id: id,
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
    return true if related_materials.find_by(dataset_id: id, datacite_list: Databank::Relationship::NEW_VERSION_OF)

    RelatedMaterial.create(dataset_id: id,
                           material_type: Databank::MaterialType::DATASET,
                           selected_type: Databank::MaterialType::DATASET,
                           datacite_list: Databank::Relationship::NEW_VERSION_OF,
                           uri: previous.identifier,
                           uri_type: "DOI",
                           citation: previous.plain_text_citation,
                           link: "https://doi.org/#{previous.identifier}")
    if related_materials.find_by(dataset_id: previous.id, datacite_list: Databank::Relationship::PREVIOUS_VERSION_OF)
      return true
    end

    RelatedMaterial.create(dataset_id: previous.id,
                           material_type: Databank::MaterialType::DATASET,
                           selected_type: Databank::MaterialType::DATASET,
                           datacite_list: Databank::Relationship::PREVIOUS_VERSION_OF,
                           uri: identifier,
                           uri_type: "DOI",
                           citation: plain_text_citation,
                           link: "https://doi.org/#{identifier}")
  end

  def add_version_files(previous:)
    return true if version_files.count.positive?

    previous.datafiles.each do |datafile|
      VersionFile.create(dataset_id: id, datafile_id: datafile.id, selected: false)
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
