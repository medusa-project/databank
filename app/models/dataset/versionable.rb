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
