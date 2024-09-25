# frozen_string_literal: true

# Represents the group of versions of a dataset, in an ordered chain of versions
class VersionGroup

  attr_accessor :dataset, :group_hash, :latest_published_version

  # @param [Dataset] dataset the dataset to create the group for
  # @return [VersionGroup] the group of versions
  def initialize(dataset)
    self.dataset = dataset
    self_version_entry = dataset.related_version_entry_hash
    self_version_entry[:selected] = true
    self.group_hash = Hash.new
    group_hash[:status] = "ok"
    group_hash[:entries] = [self_version_entry]

    # follow daisy chain of previous versions
    current_dataset = dataset
    current_group_count = 0
    max_group_count = 50

    while current_dataset && current_group_count < max_group_count
      previous_dataset = current_dataset.previous_idb_dataset
      break if previous_dataset.nil? || previous_dataset == current_dataset

      current_group_count += 1
      group_hash[:entries] << previous_dataset.related_version_entry_hash if previous_dataset
      current_dataset = previous_dataset
    end

    # reset pointer for chain of next versions
    current_dataset = dataset
    current_group_count = 0
    while current_dataset
      next_dataset = current_dataset.next_idb_dataset
      break if next_dataset.nil? || next_dataset == current_dataset

      current_group_count += 1
      group_hash[:entries] << next_dataset.related_version_entry_hash
      # go to next, if it exists, else set control to nil and break
      current_dataset = next_dataset
    end
    (group_hash[:entries].sort_by! {|k| k[:version] }).reverse!
    # set latest published version
    # if there is only one entry, and it is published, it is the latest published version
    # if there is only one entry, and it is a draft, there is no latest published version
    # if there are more than one entry, and the first is published, the first is the latest published version
    # if there are more than one entry, and the first is a draft, the second is the latest published version
    self.latest_published_version = nil
    group_hash[:entries].each do |entry|
      candidate_dataset = Dataset.find_by(key: entry[:key])
      if candidate_dataset.metadata_public?
        self.latest_published_version = candidate_dataset
        break
      end
    end
  end
end
