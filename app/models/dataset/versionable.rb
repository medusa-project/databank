# frozen_string_literal: true

##
# This module is used to manage the versioning of datasets.
# It is used in the Dataset model.

module Dataset::Versionable
  extend ActiveSupport::Concern
  attr_accessor :version_group

  ##
  # Adds version metadata copy
  # This method sets the metadata based on the previous version of the dataset
  # It then saves the dataset
  # @param [Dataset] previous the previous version of the dataset
  def add_version_metadata_copy(previous:)
    return true if title == previous.title

    previous_version_number = previous.dataset_version.to_i
    version_number = previous_version_number + 1
    identifier_base = previous.identifier.chop
    self.title = previous.title
    self.creator_text = previous.creator_text
    self.identifier = "#{identifier_base}#{version_number}"
    self.publisher = previous.publisher
    self.description = previous.description
    self.license = previous.license
    self.corresponding_creator_name = "researcher1"
    self.corresponding_creator_email = "researcher1@mailinator.com"
    self.keywords = previous.keywords
    self.publication_state = Databank::PublicationState::TempSuppress::VERSION
    self.curator_hold = true
    self.release_date = nil
    self.embargo = Databank::PublicationState::Embargo::NONE
    self.is_test = previous.is_test
    self.is_import = false
    self.tombstone_date = nil
    self.hold_state = Databank::PublicationState::TempSuppress::VERSION
    self.medusa_dataset_dir = nil
    self.dataset_version =  version_number.to_s
    self.suppress_changelog = false
    self.subject = previous.subject
    self.org_creators = previous.org_creators
    self.data_curation_network = false
    save
  end

  def destroy_relationship_with_previous_version
    return true if previous_idb_dataset.nil?

    prev_relation = previous_idb_dataset.related_materials.find_by(datacite_list: Databank::Relationship::PREVIOUS_VERSION_OF)
    prev_relation&.destroy
  end

  ##
  # send email to notify depositor that dataset version is approved
  def send_approve_version
    notification = DatabankMailer.approve_version(dataset_key: self.key)
    notification.deliver_now
  end

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

  def mark_version_files_initiated(files_to_copy:)
    files_to_copy.each do |file_to_copy|
      file_to_copy.update_attribute(:initiated, true)
    end
  end

  def remove_related_reference
    RelatedMaterial.where(uri: identifier).destroy_all
  end

  def copy_version_files
    selected_files = version_files.select(&:selected)
    incomplete_files = selected_files.reject(&:complete?)
    return true if incomplete_files.count.zero?

    incomplete_files.each(&:copy_file)
    if Application.server_envs.include?(Rails.env)
      files_copied_email = DatabankMailer.notify_version_copy_complete(dataset_key: key)
      files_copied_email.deliver_now
    else
      Rails.logger.warn("skipping version copy email in #{Rails.env} for #{key}")
    end
  end
  handle_asynchronously :copy_version_files

  def related_version_entry_hash
    # version_group[:group_hash] is an array of hashes
    self_version = dataset_version.to_i

    self_version = 1 if !self_version || self_version < 1

    {version:           self_version,
     key:               key,
     publication_state: publication_state,
     selected:          false,
     doi:               identifier || "not yet set",
     version_comment:   version_comment || "",
     publication_date:  release_date ? release_date.iso8601 : "not yet set"}
  end

  def ensure_version_group
    self.version_group ||= VersionGroup.new(self)
  end

  def update_version_group
    self.version_group = VersionGroup.new(self)
  end

  def has_newer_version?
    ensure_version_group
    return false if self.version_group.latest_published_version.nil?

    return false if self.version_group.group_hash[:entries].length < 2

    return false unless self.dataset_version&.to_i&.positive?

    if Databank::PublicationState::DRAFT_ARRAY.include?(self.version_group.group_hash[:entries][0][:publication_state])
      (self.version_group.group_hash[:entries][1][:version]).to_i > dataset_version.to_i
    else
      (self.version_group.group_hash[:entries][0][:version]).to_i > dataset_version.to_i
    end

  end

  def version_eligible_for_review?
    publication_state == Databank::PublicationState::TempSuppress::VERSION &&
      hold_state == Databank::PublicationState::TempSuppress::NONE
  end

  def is_most_recent_version
    return false if Databank::PublicationState::DRAFT_ARRAY.include?(publication_state)

    ensure_version_group
    if self.version_group.group_hash[:entries].length > 1
      if Databank::PublicationState::DRAFT_ARRAY.include?(self.version_group.group_hash[:entries][0][:publication_state])
        (version_group.group_hash[:entries][1])[:version] == dataset_version.to_i
      else
        (version_group.group_hash[:entries][0])[:version] == dataset_version.to_i
      end
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
    begin
      request_version_email = DatabankMailer.request_version(dataset_key: key)
      request_version_email.deliver_now
      acknowledge_v_request_email = DatabankMailer.acknowledge_request_version(dataset_key: key)
      acknowledge_v_request_email.deliver_now
    rescue Net::SMTPSyntaxError => e
      Rails.logger.warn(e.message)
      Rails.logger.warn("could not version request mail #{params}")
    rescue StandardError => e
      Rails.logger.warn("error while trying to send version_request_emails #{e.message}")
      raise e
    end
  end

  def add_version_nested_objects(previous:)
    return true if creators.count.positive?

    previous.creators.each do |creator|
      Creator.create(dataset_id:        id,
                     family_name:       creator.family_name,
                     given_name:        creator.given_name,
                     institution_name:  creator.institution_name,
                     identifier:        creator.identifier,
                     type_of:           creator.type_of,
                     row_order:         creator.row_order,
                     email:             creator.email,
                     is_contact:        creator.is_contact,
                     row_position:      creator.row_position,
                     identifier_scheme: creator.identifier_scheme)
    end

    previous.funders.each do |funder|
      Funder.create(dataset_id:        id,
                    name:              funder.name,
                    identifier:        funder.identifier,
                    identifier_scheme: funder.identifier_scheme,
                    grant:             funder.grant,
                    code:              funder.code)
    end

    previous.related_materials.sort_by(&:created_at).each do |material|
      next if material.datacite_list == Databank::Relationship::NEW_VERSION_OF
      next if material.datacite_list == Databank::Relationship::PREVIOUS_VERSION_OF

      RelatedMaterial.create(dataset_id:    id,
                             material_type: material.material_type,
                             availability:  material.availability,
                             link:          material.link,
                             uri:           material.uri,
                             uri_type:      material.uri_type,
                             citation:      material.citation,
                             selected_type: material.selected_type,
                             datacite_list: material.datacite_list,
                             feature:       material.feature,
                             note:          material.note)
    end
    save
  end

  def is_unconfirmed_version?
    publication_state == Databank::PublicationState::TempSuppress::VERSION || hold_state == Databank::PublicationState::TempSuppress::VERSION
  end

  def add_version_relationships(previous:)
    return true if related_materials.find_by(dataset_id: id, datacite_list: Databank::Relationship::NEW_VERSION_OF)

    RelatedMaterial.create(dataset_id:    id,
                           material_type: Databank::MaterialType::DATASET,
                           selected_type: Databank::MaterialType::DATASET,
                           datacite_list: Databank::Relationship::NEW_VERSION_OF,
                           uri:           previous.identifier,
                           uri_type:      "DOI",
                           citation:      previous.plain_text_citation,
                           link:          "https://doi.org/#{previous.identifier}")

    if related_materials.find_by(dataset_id: previous.id, datacite_list: Databank::Relationship::PREVIOUS_VERSION_OF)
      return true
    end

    RelatedMaterial.create(dataset_id:    previous.id,
                           material_type: Databank::MaterialType::DATASET,
                           selected_type: Databank::MaterialType::DATASET,
                           datacite_list: Databank::Relationship::PREVIOUS_VERSION_OF,
                           uri:           identifier,
                           uri_type:      "DOI",
                           citation:      plain_text_citation,
                           link:          "https://doi.org/#{identifier}")
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

    return nil if next_version_material.dataset.publication_state == Databank::PublicationState::TempSuppress::VERSION

    Dataset.find_by(identifier: next_version_material.uri)
  end
end
